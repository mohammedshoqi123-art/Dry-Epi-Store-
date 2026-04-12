-- 007_restore_missing_policies.sql
-- Restores policies dropped by 006_fix_permissions.sql but not recreated
BEGIN;

-- PROFILES: Allow new user to insert their own profile during signup
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
CREATE POLICY "profiles_insert_self" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- PROFILES: Allow users to see their own profile
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (id = auth.uid());

-- PROFILES: Allow governorate users to see profiles in their governorate
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
CREATE POLICY "profiles_select_governorate" ON profiles
  FOR SELECT USING (
    public.user_role() = 'governorate' AND
    governorate_id = public.user_governorate_id()
  );

-- PROFILES: Allow users to update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (id = auth.uid());

-- FORMS: Allow authenticated users to see active forms
DROP POLICY IF EXISTS "forms_select_all" ON forms;
CREATE POLICY "forms_select_all" ON forms
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

-- SUBMISSIONS: Allow users to see their own submissions
DROP POLICY IF EXISTS "submissions_select_own" ON form_submissions;
CREATE POLICY "submissions_select_own" ON form_submissions
  FOR SELECT USING (submitted_by = auth.uid());

-- SUBMISSIONS: Allow users to update their own drafts
DROP POLICY IF EXISTS "submissions_update_own_draft" ON form_submissions;
CREATE POLICY "submissions_update_own_draft" ON form_submissions
  FOR UPDATE USING (
    submitted_by = auth.uid() AND status = 'draft'
  );

-- GOVERNORATES: Allow all authenticated users to see governorates
DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- DISTRICTS: Allow all authenticated users to see districts
DROP POLICY IF EXISTS "districts_select_all" ON districts;
CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- SHORTAGES: Allow all authenticated users to see shortages
DROP POLICY IF EXISTS "shortages_select_all_auth" ON supply_shortages;
CREATE POLICY "shortages_select_all_auth" ON supply_shortages
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- SHORTAGES: Allow authenticated users to insert shortages
DROP POLICY IF EXISTS "shortages_insert_auth" ON supply_shortages;
CREATE POLICY "shortages_insert_auth" ON supply_shortages
  FOR INSERT WITH CHECK (reported_by = auth.uid());

-- AUDIT: Allow system to insert audit logs
DROP POLICY IF EXISTS "audit_insert_system" ON audit_logs;
CREATE POLICY "audit_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- HEALTH FACILITIES: Allow all authenticated users to see facilities
DROP POLICY IF EXISTS "facilities_select_all" ON health_facilities;
CREATE POLICY "facilities_select_all" ON health_facilities
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Ensure execute permissions on helper functions
GRANT EXECUTE ON FUNCTION public.user_role() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_governorate_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_district_id() TO anon, authenticated, service_role;

COMMIT;
