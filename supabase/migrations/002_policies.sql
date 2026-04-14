-- ============================================================
-- EPI Supervisor — RLS Policies, Functions, Grants & Indexes
-- Consolidated from migrations 006-013
-- ============================================================

BEGIN;

-- ============================================================
-- 1. HELPER FUNCTIONS
-- ============================================================

-- User role lookup (used by all RLS policies)
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.user_governorate_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.user_district_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- Optimized user context (single query for all RLS checks)
CREATE OR REPLACE FUNCTION public.get_user_context()
RETURNS TABLE(user_id UUID, role user_role, governorate_id UUID, district_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, role, governorate_id, district_id
  FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- ============================================================
-- 2. RLS POLICIES
-- ============================================================

-- ─── PROFILES ──────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_insert_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;

CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_insert_admin" ON profiles FOR INSERT WITH CHECK (public.user_role() = 'admin');
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (public.user_role() = 'admin');
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (public.user_role() = 'admin');
CREATE POLICY "profiles_delete_admin" ON profiles FOR DELETE USING (public.user_role() = 'admin');

-- ─── GOVERNORATES ──────────────────────────────────────
DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
DROP POLICY IF EXISTS "governorates_modify_admin" ON governorates;

CREATE POLICY "governorates_select_all" ON governorates FOR SELECT USING (true);
CREATE POLICY "governorates_modify_admin" ON governorates FOR ALL USING (public.user_role() = 'admin');

-- ─── DISTRICTS ─────────────────────────────────────────
DROP POLICY IF EXISTS "districts_select_all" ON districts;
DROP POLICY IF EXISTS "districts_modify_admin" ON districts;

CREATE POLICY "districts_select_all" ON districts FOR SELECT USING (true);
CREATE POLICY "districts_modify_admin" ON districts FOR ALL USING (public.user_role() = 'admin');

-- ─── FORMS ─────────────────────────────────────────────
DROP POLICY IF EXISTS "forms_select_all" ON forms;
DROP POLICY IF EXISTS "forms_modify_admin" ON forms;

CREATE POLICY "forms_select_all" ON forms FOR SELECT USING (is_active = true OR public.user_role() = 'admin');
CREATE POLICY "forms_modify_admin" ON forms FOR ALL USING (public.user_role() IN ('admin', 'central'));

-- ─── FORM SUBMISSIONS (role-based visibility) ──────────
DROP POLICY IF EXISTS "submissions_insert_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_hierarchical" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_own_or_admin" ON form_submissions;

-- Insert: anyone authenticated can submit
CREATE POLICY "submissions_insert_own" ON form_submissions
  FOR INSERT WITH CHECK (submitted_by = auth.uid());

-- Select: hierarchical — admin sees all, central sees all, governorate sees own gov, etc.
CREATE POLICY "submissions_select_hierarchical" ON form_submissions FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true
    WHEN 'central' THEN true
    WHEN 'governorate' THEN governorate_id = public.user_governorate_id()
    WHEN 'district' THEN district_id = public.user_district_id()
    WHEN 'data_entry' THEN submitted_by = auth.uid()
    ELSE false
  END
);

-- Update: only own submissions, or admin/central can update any
CREATE POLICY "submissions_update_own_or_admin" ON form_submissions FOR UPDATE USING (
  submitted_by = auth.uid() OR public.user_role() IN ('admin', 'central')
);

-- ─── SUPPLY SHORTAGES ─────────────────────────────────
DROP POLICY IF EXISTS "shortages_select_hierarchical" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_insert_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_update_hierarchical" ON supply_shortages;

CREATE POLICY "shortages_select_hierarchical" ON supply_shortages FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true
    WHEN 'central' THEN true
    WHEN 'governorate' THEN governorate_id = public.user_governorate_id()
    WHEN 'district' THEN district_id = public.user_district_id()
    ELSE reported_by = auth.uid()
  END
);
CREATE POLICY "shortages_insert_auth" ON supply_shortages FOR INSERT WITH CHECK (reported_by = auth.uid());
CREATE POLICY "shortages_update_hierarchical" ON supply_shortages FOR UPDATE USING (
  reported_by = auth.uid() OR public.user_role() IN ('admin', 'central')
);

-- ─── HEALTH FACILITIES ────────────────────────────────
ALTER TABLE IF EXISTS health_facilities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "facilities_select_all" ON health_facilities;
CREATE POLICY "facilities_select_all" ON health_facilities FOR SELECT USING (true);

-- ─── AUDIT LOGS ───────────────────────────────────────
DROP POLICY IF EXISTS "audit_select_admin" ON audit_logs;
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT USING (public.user_role() IN ('admin', 'central'));

-- ─── PAGES ────────────────────────────────────────────
DROP POLICY IF EXISTS "Pages viewable by authenticated" ON pages;
DROP POLICY IF EXISTS "Pages manageable by admins" ON pages;
CREATE POLICY "pages_select_active" ON pages FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
CREATE POLICY "pages_manage_admin" ON pages FOR ALL USING (public.user_role() = 'admin');

-- ─── APP SETTINGS ─────────────────────────────────────
DROP POLICY IF EXISTS "Settings viewable by authenticated" ON app_settings;
DROP POLICY IF EXISTS "Settings manageable by admins" ON app_settings;
CREATE POLICY "settings_select_auth" ON app_settings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "settings_manage_admin" ON app_settings FOR ALL USING (public.user_role() = 'admin');

-- ─── REFERENCES (NEW) ─────────────────────────────────
DROP POLICY IF EXISTS "references_select_active" ON doc_references;
DROP POLICY IF EXISTS "references_manage_admin" ON doc_references;

CREATE POLICY "references_select_active" ON doc_references
  FOR SELECT USING (is_active = true AND deleted_at IS NULL);

CREATE POLICY "references_manage_admin" ON doc_references
  FOR ALL USING (public.user_role() = 'admin');

-- ============================================================
-- 3. STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('submission-photos', 'submission-photos', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('references', 'references', false, 52428800, ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Users can upload own submission photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own submission photos" ON storage.objects;
DROP POLICY IF EXISTS "Admins can upload references" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can view references" ON storage.objects;

CREATE POLICY "Users can upload own submission photos" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'submission-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can view own submission photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'submission-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Admins can upload references" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'references' AND public.user_role() = 'admin');
CREATE POLICY "Authenticated can view references" ON storage.objects
  FOR SELECT USING (bucket_id = 'references' AND auth.uid() IS NOT NULL);

-- ============================================================
-- 4. PERFORMANCE INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_governorate ON profiles(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_district ON profiles(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_user ON form_submissions(submitted_by) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_form ON form_submissions(form_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_gov ON form_submissions(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_district ON form_submissions(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_date ON form_submissions(submitted_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_shortages_severity ON supply_shortages(severity) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_gov ON supply_shortages(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_audit_user_date ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_references_category ON doc_references(category) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_references_active ON doc_references(is_active) WHERE deleted_at IS NULL;

-- Full-text search on forms
CREATE INDEX IF NOT EXISTS idx_forms_title_search ON forms USING gin(to_tsvector('arabic', coalesce(title_ar,'') || ' ' || coalesce(title_en,'')));

-- ============================================================
-- 5. GRANTS
-- ============================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

GRANT SELECT ON governorates TO authenticated;
GRANT SELECT ON districts TO authenticated;
GRANT SELECT, UPDATE ON profiles TO authenticated;
GRANT SELECT ON forms TO authenticated;
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;
GRANT SELECT ON audit_logs TO authenticated;
GRANT SELECT ON health_facilities TO authenticated;
GRANT SELECT ON pages TO authenticated;
GRANT SELECT ON app_settings TO authenticated;
GRANT SELECT ON doc_references TO authenticated;
GRANT INSERT ON profiles TO anon;

COMMIT;
