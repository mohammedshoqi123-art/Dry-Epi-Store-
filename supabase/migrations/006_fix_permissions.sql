-- ============================================================
-- EPI Supervisor — Fix Permissions & RLS
-- Version: 2.0.1
-- هذا الملف يصلح مشاكل الصلاحيات والـ RLS
-- ============================================================

BEGIN;

-- ============================================================
-- 1. GRANT PERMISSIONS (الإصلاح الأهم)
-- ============================================================

-- Schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA extensions TO anon, authenticated;

-- Governorates: الجميع يمكنهم القراءة
GRANT SELECT ON governorates TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON governorates TO authenticated;

-- Districts: الجميع يمكنهم القراءة
GRANT SELECT ON districts TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON districts TO authenticated;

-- Forms: الجميع يمكنهم القراءة
GRANT SELECT ON forms TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON forms TO authenticated;

-- Profiles: المستخدمون المسجلون يمكنهم القراءة والتعديل
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;

-- Form Submissions: المستخدمون المسجلون
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;

-- Supply Shortages: المستخدمون المسجلون
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;

-- Audit Logs: القراءة للمشرفين فقط (عبر RLS)، الكتابة للنظام
GRANT SELECT ON audit_logs TO authenticated;
GRANT INSERT ON audit_logs TO authenticated;

-- Sequences (needed for inserts)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- ============================================================
-- 2. DEFAULT PRIVILEGES (للجداول المستقبلية)
-- ============================================================

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO authenticated;

-- ============================================================
-- 3. FIX: إضافة policy ناقصة لـ profiles
-- ============================================================

-- السماح لمستخدمي district بعرض profiles في منطقتهم
DROP POLICY IF EXISTS "profiles_select_district" ON profiles;
CREATE POLICY "profiles_select_district" ON profiles
  FOR SELECT USING (
    public.user_role() = 'district' AND
    district_id = public.user_district_id()
  );

-- ============================================================
-- 4. FIX: السماح بقراءة profiles لجميع المستخدمين المسجلين
--    (مطلوب لعرض أسماء المُرسِلين في الإرساليات)
-- ============================================================

-- إزالة policies القديمة المحدودة
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_central" ON profiles;
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
DROP POLICY IF EXISTS "profiles_select_district" ON profiles;

-- policy موحدة: المستخدمون المسجلون يمكنهم قراءة كل الـ profiles
-- (البيانات الحساسة محمية بـ application-level filtering)
CREATE POLICY "profiles_select_authenticated" ON profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- policies الإدراج والتعديل تبقى كما هي
-- profiles_insert_self, profiles_insert_admin, profiles_update_own, profiles_update_admin

-- ============================================================
-- 5. FIX: ضمان أن SECURITY DEFINER functions يعملون
-- ============================================================

-- إعادة إنشاء user_role() مع ضمان SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- إعادة إنشاء user_governorate_id()
CREATE OR REPLACE FUNCTION public.user_governorate_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- إعادة إنشاء user_district_id()
CREATE OR REPLACE FUNCTION public.user_district_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- تأمين الصلاحيات على الدوال
REVOKE ALL ON FUNCTION public.user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.user_governorate_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.user_district_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_role() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_governorate_id() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.user_district_id() TO anon, authenticated;

-- ============================================================
-- 6. FIX: تحسين handle_new_user trigger + auto-promote admin
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
  -- تحديد الدور: إذا الإيميل ضمن قائمة المشرفين → admin
  IF NEW.email = ANY(admin_emails) THEN
    user_role_val := 'admin';
  ELSE
    user_role_val := COALESCE(
      (NEW.raw_user_meta_data->>'role')::user_role,
      'data_entry'
    );
  END IF;

  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    user_role_val
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: % (SQLSTATE: %)', NEW.id, SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 6b. دالة يدوية لترقية مستخدم موجود إلى admin
-- ============================================================

CREATE OR REPLACE FUNCTION promote_to_admin(user_email TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET role = 'admin', updated_at = now()
  WHERE email = user_email;

  IF NOT FOUND THEN
    RAISE NOTICE 'User with email % not found in profiles. They need to sign up first.', user_email;
  ELSE
    RAISE NOTICE 'User % promoted to admin.', user_email;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION promote_to_admin(TEXT) TO authenticated;

-- ============================================================
-- 7. FIX: ضمان أن seed data يُنشأ بشكل صحيح
-- ============================================================

-- التأكد من أن governorates و districts متاحة لـ anon (للـ signup flow)
-- هذا مهم لأن الـ app قد يحتاج قراءة المحافظات قبل تسجيل الدخول

-- إزالة policy القديمة وإنشاء policy مفتوحة أكثر
DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (true);  -- متاحة للجميع (بيانات عامة)

DROP POLICY IF EXISTS "districts_select_all" ON districts;
CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (true);  -- متاحة للجميع (بيانات عامة)

-- ============================================================
-- 8. FIX: إضافة index لتحسين الأداء
-- ============================================================

-- Index على profiles.id مدعوم بالـ FK بالفعل
-- إضافة index على form_submissions للاستعلامات الشائعة
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_by ON form_submissions(submitted_by);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status);
CREATE INDEX IF NOT EXISTS idx_submissions_governorate ON form_submissions(governorate_id);
CREATE INDEX IF NOT EXISTS idx_submissions_created_at ON form_submissions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shortages_resolved ON supply_shortages(is_resolved);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- ============================================================
-- 9. Verify: التأكد من أن كل شيء يعمل
-- ============================================================

-- فحص أن الـ policies موجودة
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE schemaname = 'public';
  RAISE NOTICE 'Total RLS policies: %', policy_count;

  IF policy_count < 10 THEN
    RAISE WARNING 'Expected at least 10 RLS policies, found %', policy_count;
  END IF;
END $$;

COMMIT;

-- ============================================================
-- بعد تطبيق هذا الملف:
-- 1. شغّل هذا الـ SQL في Supabase SQL Editor
-- 2. تأكد أن المستخدم Admin موجود (أو أنشئه عبر create-admin function)
-- 3. جرّب تسجيل الدخول في التطبيق
-- ============================================================
