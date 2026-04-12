-- ============================================================
-- 006_fix_permissions.sql
-- Fixes permission issues and removes auth.users trigger
-- (Profile creation is now handled in the app code)
-- ============================================================

BEGIN;

-- 1. Remove trigger on auth.users (not allowed in Supabase)
DROP TRIGGER IF EXISTS trg_auth_signup ON auth.users;
DROP FUNCTION IF EXISTS IF EXISTS public.handle_new_user() CASCADE;

-- 2. Drop user_role function with CASCADE (removes dependent policies)
DROP FUNCTION IF EXISTS public.user_role() CASCADE;

-- 3. Recreate user_role function
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 4. Recreate all policies that depend on user_role()

-- PROFILES
CREATE POLICY "profiles_insert_self" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (public.user_role() = 'admin');

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

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (id = auth.uid());

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (public.user_role() = 'admin');

-- GOVERNORATES
CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "governorates_modify_admin" ON governorates
  FOR ALL USING (public.user_role() = 'admin');

-- DISTRICTS
CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "districts_modify_admin" ON districts
  FOR ALL USING (public.user_role() = 'admin');

-- FORMS
CREATE POLICY "forms_select_all" ON forms
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "forms_select_admin" ON forms
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "forms_modify_admin" ON forms
  FOR ALL USING (public.user_role() = 'admin');

-- FORM_SUBMISSIONS
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
  FOR UPDATE USING (
    submitted_by = auth.uid() AND status = 'draft'
  );

CREATE POLICY "submissions_update_reviewer" ON form_submissions
  FOR UPDATE USING (
    public.user_role() = 'admin' OR
    public.user_role() = 'central' OR
    (public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()) OR
    (public.user_role() = 'district' AND district_id = public.user_district_id())
  );

-- SUPPLY_SHORTAGES
CREATE POLICY "shortages_select_all_auth" ON supply_shortages
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "shortages_insert_auth" ON supply_shortages
  FOR INSERT WITH CHECK (reported_by = auth.uid());

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

CREATE POLICY "audit_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION public.user_role() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_governorate_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_district_id() TO anon, authenticated, service_role;

COMMIT;
