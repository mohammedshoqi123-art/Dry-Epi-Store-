-- ============================================================
-- EPI Supervisor — Complete Permissions Fix
-- Version: 2.1.0
-- يحل كل مشاكل الصلاحيات في ملف واحد
-- شغّل هذا الملف مرة واحدة فقط في Supabase SQL Editor
-- ============================================================

BEGIN;

-- ============================================================
-- 1. GRANT صلاحيات PostgreSQL
-- ============================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA extensions TO anon, authenticated;

-- القراءة للجميع
GRANT SELECT ON governorates TO anon, authenticated;
GRANT SELECT ON districts TO anon, authenticated;
GRANT SELECT ON forms TO authenticated;

-- الملفات الشخصية
GRANT SELECT, UPDATE ON profiles TO authenticated;

-- الإرساليات والنواقص
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;

-- سجل التدقيق
GRANT SELECT, INSERT ON audit_logs TO authenticated;

-- Sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- Default privileges للجداول المستقبلية
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO authenticated;

-- ============================================================
-- 2. دوال مساعدة (مع DROP IF EXISTS)
-- ============================================================

-- دالة user_role
DROP FUNCTION IF EXISTS public.user_role();
CREATE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$fn$;

-- دالة user_governorate_id
DROP FUNCTION IF EXISTS public.user_governorate_id();
CREATE FUNCTION public.user_governorate_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$fn$;

-- دالة user_district_id
DROP FUNCTION IF EXISTS public.user_district_id();
CREATE FUNCTION public.user_district_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$fn$;

-- دالة promote_to_admin
DROP FUNCTION IF EXISTS promote_to_admin(TEXT);
CREATE FUNCTION promote_to_admin(user_email TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  UPDATE profiles SET role = 'admin', updated_at = now() WHERE email = user_email;
  IF NOT FOUND THEN
    RAISE NOTICE 'User % not found', user_email;
  END IF;
END;
$fn$;

-- دالة admin_update_user_role
DROP FUNCTION IF EXISTS admin_update_user_role(UUID, user_role, UUID, UUID);
CREATE FUNCTION admin_update_user_role(
  target_user_id UUID,
  new_role user_role,
  new_governorate_id UUID DEFAULT NULL,
  new_district_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can update user roles';
  END IF;
  UPDATE profiles
  SET role = new_role,
      governorate_id = COALESCE(new_governorate_id, governorate_id),
      district_id = COALESCE(new_district_id, district_id),
      updated_at = now()
  WHERE id = target_user_id;
END;
$fn$;

-- دالة admin_toggle_user_active
DROP FUNCTION IF EXISTS admin_toggle_user_active(UUID, BOOLEAN);
CREATE FUNCTION admin_toggle_user_active(target_user_id UUID, make_active BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can toggle user status';
  END IF;
  UPDATE profiles SET is_active = make_active, updated_at = now() WHERE id = target_user_id;
END;
$fn$;

-- دالة admin_delete_user
DROP FUNCTION IF EXISTS admin_delete_user(UUID);
CREATE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can delete users';
  END IF;
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete yourself';
  END IF;
  UPDATE profiles SET deleted_at = now(), is_active = false WHERE id = target_user_id;
END;
$fn$;

-- منح صلاحيات تنفيذ الدوال
GRANT EXECUTE ON FUNCTION public.user_role() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_governorate_id() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_district_id() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION promote_to_admin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_user_role(UUID, user_role, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_user_active(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_user(UUID) TO authenticated;

-- ============================================================
-- 3. TRIGGER handle_new_user (مع auto-promote admin)
-- ============================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  admin_emails TEXT[] := ARRAY['mohammedshoqi123@gmail.com'];
  user_role_val user_role;
BEGIN
  IF NEW.email = ANY(admin_emails) THEN
    user_role_val := 'admin';
  ELSE
    user_role_val := COALESCE(
      (NEW.raw_user_meta_data->>'role')::user_role,
      'data_entry'
    );
  END IF;

  INSERT INTO profiles (id, email, full_name, role, governorate_id, district_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    user_role_val,
    (NEW.raw_user_meta_data->>'governorate_id')::UUID,
    (NEW.raw_user_meta_data->>'district_id')::UUID
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 4. RLS POLICIES — حذف القديمة وإنشاء الجديدة
-- ============================================================

-- ---- Governorates: الجميع يقرأ، Admin فقط يعدّل ----

DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
DROP POLICY IF EXISTS "governorates_modify_admin" ON governorates;
DROP POLICY IF EXISTS "governorates_insert_admin" ON governorates;
DROP POLICY IF EXISTS "governorates_update_admin" ON governorates;
DROP POLICY IF EXISTS "governorates_delete_admin" ON governorates;

CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (true);

CREATE POLICY "governorates_insert_admin" ON governorates
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

CREATE POLICY "governorates_update_admin" ON governorates
  FOR UPDATE USING (public.user_role() = 'admin');

CREATE POLICY "governorates_delete_admin" ON governorates
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Districts: الجميع يقرأ، Admin فقط يعدّل ----

DROP POLICY IF EXISTS "districts_select_all" ON districts;
DROP POLICY IF EXISTS "districts_modify_admin" ON districts;
DROP POLICY IF EXISTS "districts_insert_admin" ON districts;
DROP POLICY IF EXISTS "districts_update_admin" ON districts;
DROP POLICY IF EXISTS "districts_delete_admin" ON districts;

CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (true);

CREATE POLICY "districts_insert_admin" ON districts
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

CREATE POLICY "districts_update_admin" ON districts
  FOR UPDATE USING (public.user_role() = 'admin');

CREATE POLICY "districts_delete_admin" ON districts
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Forms: المسجلين يقرأون، Admin فقط يعدّل ----

DROP POLICY IF EXISTS "forms_select_all" ON forms;
DROP POLICY IF EXISTS "forms_select_admin" ON forms;
DROP POLICY IF EXISTS "forms_modify_admin" ON forms;
DROP POLICY IF EXISTS "forms_insert_admin" ON forms;
DROP POLICY IF EXISTS "forms_update_admin" ON forms;
DROP POLICY IF EXISTS "forms_delete_admin" ON forms;

CREATE POLICY "forms_select_all" ON forms
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "forms_select_admin" ON forms
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "forms_insert_admin" ON forms
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

CREATE POLICY "forms_update_admin" ON forms
  FOR UPDATE USING (public.user_role() = 'admin');

CREATE POLICY "forms_delete_admin" ON forms
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Profiles: حسب الدور ----

DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_central" ON profiles;
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
DROP POLICY IF EXISTS "profiles_select_district" ON profiles;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;

CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "profiles_select_central" ON profiles
  FOR SELECT USING (public.user_role() = 'central');

CREATE POLICY "profiles_select_governorate" ON profiles
  FOR SELECT USING (
    public.user_role() = 'governorate' AND
    governorate_id = public.user_governorate_id()
  );

CREATE POLICY "profiles_select_district" ON profiles
  FOR SELECT USING (
    public.user_role() = 'district' AND
    district_id = public.user_district_id()
  );

CREATE POLICY "profiles_insert_self" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (id = auth.uid());

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (public.user_role() = 'admin');

CREATE POLICY "profiles_delete_admin" ON profiles
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Form Submissions ----

DROP POLICY IF EXISTS "submissions_select_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_district" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_governorate" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_central_admin" ON form_submissions;
DROP POLICY IF EXISTS "submissions_insert_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_own_draft" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_reviewer" ON form_submissions;
DROP POLICY IF EXISTS "submissions_delete_admin" ON form_submissions;

CREATE POLICY "submissions_select_own" ON form_submissions
  FOR SELECT USING (submitted_by = auth.uid());

CREATE POLICY "submissions_select_district" ON form_submissions
  FOR SELECT USING (
    public.user_role() = 'district' AND
    district_id = public.user_district_id()
  );

CREATE POLICY "submissions_select_governorate" ON form_submissions
  FOR SELECT USING (
    public.user_role() = 'governorate' AND
    governorate_id = public.user_governorate_id()
  );

CREATE POLICY "submissions_select_central_admin" ON form_submissions
  FOR SELECT USING (public.user_role() IN ('central', 'admin'));

CREATE POLICY "submissions_insert_own" ON form_submissions
  FOR INSERT WITH CHECK (
    submitted_by = auth.uid() AND
    public.user_role() IN ('data_entry', 'district', 'governorate', 'central', 'admin')
  );

CREATE POLICY "submissions_update_own_draft" ON form_submissions
  FOR UPDATE USING (submitted_by = auth.uid() AND status = 'draft');

CREATE POLICY "submissions_update_reviewer" ON form_submissions
  FOR UPDATE USING (
    public.user_role() = 'admin' OR
    public.user_role() = 'central' OR
    (public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()) OR
    (public.user_role() = 'district' AND district_id = public.user_district_id())
  );

CREATE POLICY "submissions_delete_admin" ON form_submissions
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Supply Shortages ----

DROP POLICY IF EXISTS "shortages_select_all_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_insert_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_update_hierarchy" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_delete_admin" ON supply_shortages;

CREATE POLICY "shortages_select_all_auth" ON supply_shortages
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "shortages_insert_auth" ON supply_shortages
  FOR INSERT WITH CHECK (reported_by = auth.uid());

CREATE POLICY "shortages_update_hierarchy" ON supply_shortages
  FOR UPDATE USING (
    reported_by = auth.uid() OR
    public.user_role() IN ('district', 'governorate', 'central', 'admin')
  );

CREATE POLICY "shortages_delete_admin" ON supply_shortages
  FOR DELETE USING (public.user_role() = 'admin');

-- ---- Audit Logs ----

DROP POLICY IF EXISTS "audit_select_admin" ON audit_logs;
DROP POLICY IF EXISTS "audit_select_central" ON audit_logs;
DROP POLICY IF EXISTS "audit_insert_system" ON audit_logs;

CREATE POLICY "audit_select_admin" ON audit_logs
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "audit_select_central" ON audit_logs
  FOR SELECT USING (public.user_role() = 'central');

CREATE POLICY "audit_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- 5. Indexes للأداء
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_submissions_submitted_by ON form_submissions(submitted_by);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status);
CREATE INDEX IF NOT EXISTS idx_submissions_governorate ON form_submissions(governorate_id);
CREATE INDEX IF NOT EXISTS idx_submissions_created_at ON form_submissions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shortages_resolved ON supply_shortages(is_resolved);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

COMMIT;
