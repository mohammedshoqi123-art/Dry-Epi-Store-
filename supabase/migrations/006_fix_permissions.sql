-- 006_fix_permissions.sql

BEGIN;

-- 1. احذف الدالة مع كل الـ Policies المعتمدة عليها
DROP FUNCTION IF EXISTS public.user_role() CASCADE;

-- 2. أعد إنشاء الدالة
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 3. أعد إنشاء كل الـ Policies اللي كانت تعتمد عليها

-- PROFILES
CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (public.user_role() = 'admin' OR auth.uid() = id);

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (public.user_role() = 'admin');

-- GOVERNORATES
CREATE POLICY "governorates_modify_admin" ON governorates
  FOR ALL USING (public.user_role() = 'admin');

-- DISTRICTS
CREATE POLICY "districts_modify_admin" ON districts
  FOR ALL USING (public.user_role() = 'admin');

-- FORMS
CREATE POLICY "forms_select_admin" ON forms
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "forms_modify_admin" ON forms
  FOR ALL USING (public.user_role() = 'admin');

-- FORM_SUBMISSIONS
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

CREATE POLICY "submissions_update_reviewer" ON form_submissions
  FOR UPDATE USING (
    public.user_role() = 'admin' OR
    public.user_role() = 'central' OR
    (public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()) OR
    (public.user_role() = 'district' AND district_id = public.user_district_id())
  );

-- SUPPLY_SHORTAGES
CREATE POLICY "shortages_update_hierarchy" ON supply_shortages
  FOR UPDATE USING (
    reported_by = auth.uid() OR
    public.user_role() IN ('district', 'governorate', 'central', 'admin')
  );

-- AUDIT_LOGS
CREATE POLICY "audit_select_admin" ON audit_logs
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "audit_select_central" ON audit_logs
  FOR SELECT USING (public.user_role() = 'central');

-- HEALTH_FACILITIES (جديد من مشروعك)
CREATE POLICY "facilities_modify_admin" ON health_facilities
  FOR ALL USING (public.user_role() = 'admin');

-- 4. الصلاحيات
GRANT EXECUTE ON FUNCTION public.user_role() TO anon, authenticated, service_role;

COMMIT;
