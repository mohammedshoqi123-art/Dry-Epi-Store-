-- ============================================================
-- EPI Supervisor — Tighten Permissions
-- Version: 2.0.2
-- تضييق الصلاحيات بشكل صحيح حسب الأدوار
-- ============================================================

BEGIN;

-- ============================================================
-- 1. تضييق GRANT على الجداول الحساسة
-- ============================================================

-- إلغاء الصلاحيات المفتوحة من migration 006
REVOKE INSERT, UPDATE, DELETE ON governorates FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON districts FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON forms FROM authenticated;

-- إعادة منح فقط القراءة + RLS يتحكم بالباقي
-- governorates: القراءة للجميع (حتى anon)
GRANT SELECT ON governorates TO anon, authenticated;
-- فقط admin عبر SECURITY DEFINER function أو service_role يقدر يعدل

-- districts: القراءة للجميع
GRANT SELECT ON districts TO anon, authenticated;

-- forms: القراءة للمسجلين
GRANT SELECT ON forms TO authenticated;
-- فقط admin يعدل (عبر Edge Function بـ service_role)

-- profiles: القراءة والتحديث فقط (INSERT عبر trigger)
GRANT SELECT, UPDATE ON profiles TO authenticated;

-- submissions: القراءة والإدراج والتحديث (RLS يحدد مَن)
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;
GRANT DELETE ON form_submissions TO authenticated; -- admin فقط عبر RLS

-- shortages: نفس الشيء
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;
GRANT DELETE ON supply_shortages TO authenticated; -- admin فقط عبر RLS

-- audit_logs: القراءة لل admin/central فقط عبر RLS
GRANT SELECT ON audit_logs TO authenticated;
GRANT INSERT ON audit_logs TO authenticated; -- للنظام عبر trigger

-- ============================================================
-- 2. DELETE policies (Admin فقط)
-- ============================================================

-- Submissions: admin فقط يحذف
DROP POLICY IF EXISTS "submissions_delete_admin" ON form_submissions;
CREATE POLICY "submissions_delete_admin" ON form_submissions
  FOR DELETE USING (public.user_role() = 'admin');

-- Shortages: admin فقط يحذف
DROP POLICY IF EXISTS "shortages_delete_admin" ON supply_shortages;
CREATE POLICY "shortages_delete_admin" ON supply_shortages
  FOR DELETE USING (public.user_role() = 'admin');

-- Governorates: admin فقط يعدل ويحذف
DROP POLICY IF EXISTS "governorates_insert_admin" ON governorates;
CREATE POLICY "governorates_insert_admin" ON governorates
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

DROP POLICY IF EXISTS "governorates_update_admin" ON governorates;
CREATE POLICY "governorates_update_admin" ON governorates
  FOR UPDATE USING (public.user_role() = 'admin');

DROP POLICY IF EXISTS "governorates_delete_admin" ON governorates;
CREATE POLICY "governorates_delete_admin" ON governorates
  FOR DELETE USING (public.user_role() = 'admin');

-- Districts: admin فقط يعدل ويحذف
DROP POLICY IF EXISTS "districts_insert_admin" ON districts;
CREATE POLICY "districts_insert_admin" ON districts
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

DROP POLICY IF EXISTS "districts_update_admin" ON districts;
CREATE POLICY "districts_update_admin" ON districts
  FOR UPDATE USING (public.user_role() = 'admin');

DROP POLICY IF EXISTS "districts_delete_admin" ON districts;
CREATE POLICY "districts_delete_admin" ON districts
  FOR DELETE USING (public.user_role() = 'admin');

-- Forms: admin فقط يعدل ويحذف
DROP POLICY IF EXISTS "forms_insert_admin" ON forms;
CREATE POLICY "forms_insert_admin" ON forms
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

DROP POLICY IF EXISTS "forms_update_admin" ON forms;
CREATE POLICY "forms_update_admin" ON forms
  FOR UPDATE USING (public.user_role() = 'admin');

DROP POLICY IF EXISTS "forms_delete_admin" ON forms;
CREATE POLICY "forms_delete_admin" ON forms
  FOR DELETE USING (public.user_role() = 'admin');

-- ============================================================
-- 3. تضييق profiles
-- ============================================================

-- إزالة policy المفتوحة القديمة
DROP POLICY IF EXISTS "profiles_select_authenticated" ON profiles;

-- القراءة: admin يشوف الكل، البقية يشوفون بس أنفسهم
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "profiles_select_central" ON profiles
  FOR SELECT USING (public.user_role() = 'central');

-- Governorate level: يشوف profiles في محافظته
CREATE POLICY "profiles_select_governorate" ON profiles
  FOR SELECT USING (
    public.user_role() = 'governorate' AND
    governorate_id = public.user_governorate_id()
  );

-- District level: يشوف profiles في مديريته
CREATE POLICY "profiles_select_district" ON profiles
  FOR SELECT USING (
    public.user_role() = 'district' AND
    district_id = public.user_district_id()
  );

-- الإدراج: المستخدم ينشئ profile نفسه فقط
-- (موجود: profiles_insert_self)

-- التحديث: المستخدم يعدّل نفسه + admin يعدّل الجميع
-- (موجود: profiles_update_own, profiles_update_admin)

-- admin فقط يحذف profiles
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;
CREATE POLICY "profiles_delete_admin" ON profiles
  FOR DELETE USING (public.user_role() = 'admin');

-- ============================================================
-- 4. Audit logs: admin + central فقط يقرؤون
-- ============================================================

-- (موجود: audit_select_admin, audit_select_central)

-- ============================================================
-- 5. دوال مساعدة للأدمن (تتجاوز RLS عبر SECURITY DEFINER)
-- ============================================================

-- تحديث دور مستخدم (admin فقط)
CREATE OR REPLACE FUNCTION admin_update_user_role(
  target_user_id UUID,
  new_role user_role,
  new_governorate_id UUID DEFAULT NULL,
  new_district_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- التحقق من أن المستدعي admin
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can update user roles';
  END IF;

  UPDATE profiles
  SET
    role = new_role,
    governorate_id = COALESCE(new_governorate_id, governorate_id),
    district_id = COALESCE(new_district_id, district_id),
    updated_at = now()
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', target_user_id;
  END IF;
END;
$$;

-- تعطيل/تفعيل مستخدم (admin فقط)
CREATE OR REPLACE FUNCTION admin_toggle_user_active(
  target_user_id UUID,
  make_active BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can toggle user status';
  END IF;

  UPDATE profiles
  SET
    is_active = make_active,
    updated_at = now()
  WHERE id = target_user_id;
END;
$$;

-- حذف مستخدم (admin فقط — حذف ناعم)
CREATE OR REPLACE FUNCTION admin_delete_user(
  target_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.user_role() != 'admin' THEN
    RAISE EXCEPTION 'Only admin can delete users';
  END IF;

  -- لا تسمح بحذف النفس
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- حذف ناعم
  UPDATE profiles
  SET deleted_at = now(), is_active = false
  WHERE id = target_user_id;
END;
$$;

-- منح صلاحيات تنفيذ الدوال (الأمان عبر SECURITY DEFINER)
GRANT EXECUTE ON FUNCTION admin_update_user_role(UUID, user_role, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_user_active(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_user(UUID) TO authenticated;

-- ============================================================
-- 6. تحديث trigger handle_new_user لتعيين محافظات/مديرات
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

COMMIT;
