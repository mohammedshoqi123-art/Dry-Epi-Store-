-- ============================================================
-- EPI Supervisor — Unified Database Schema (v3.0)
-- Consolidated: Schema + RLS + Functions + Triggers
-- ⚠️ Run this in Supabase SQL Editor
-- ============================================================

BEGIN;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================
-- 2. ENUMS
-- ============================================================
DO $$ BEGIN CREATE TYPE user_role AS ENUM ('admin','central','governorate','district','data_entry');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE submission_status AS ENUM ('draft','submitted','reviewed','approved','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE shortage_severity AS ENUM ('critical','high','medium','low');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE audit_action AS ENUM ('create','read','update','delete','login','logout','submit','approve','reject','export');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 3. TABLES
-- ============================================================

-- governorates
CREATE TABLE IF NOT EXISTS governorates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
  geometry GEOMETRY(MultiPolygon, 4326),
  center_lat DOUBLE PRECISION, center_lng DOUBLE PRECISION, population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
  CONSTRAINT governorates_code_check CHECK (length(code) >= 2)
);

-- districts
CREATE TABLE IF NOT EXISTS districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate_id UUID NOT NULL REFERENCES governorates(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
  geometry GEOMETRY(MultiPolygon, 4326),
  center_lat DOUBLE PRECISION, center_lng DOUBLE PRECISION, population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
  CONSTRAINT districts_code_check CHECK (length(code) >= 2)
);

-- profiles
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE, full_name TEXT NOT NULL, phone TEXT,
  role user_role NOT NULL DEFAULT 'data_entry',
  governorate_id UUID REFERENCES governorates(id), district_id UUID REFERENCES districts(id),
  avatar_url TEXT, is_active BOOLEAN NOT NULL DEFAULT true, last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
  CONSTRAINT profiles_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT profiles_full_name_check CHECK (length(full_name) >= 2)
);

-- forms
CREATE TABLE IF NOT EXISTS forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar TEXT NOT NULL, title_en TEXT NOT NULL,
  description_ar TEXT, description_en TEXT,
  schema JSONB NOT NULL DEFAULT '{}', version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true, requires_gps BOOLEAN NOT NULL DEFAULT false,
  requires_photo BOOLEAN NOT NULL DEFAULT false, max_photos INTEGER DEFAULT 5,
  allowed_roles user_role[] NOT NULL DEFAULT ARRAY['data_entry','district','governorate','central','admin']::user_role[],
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
  CONSTRAINT forms_schema_check CHECK (jsonb_typeof(schema) = 'object'),
  CONSTRAINT forms_title_check CHECK (length(title_ar) >= 2)
);

-- form_submissions
CREATE TABLE IF NOT EXISTS form_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id UUID NOT NULL REFERENCES forms(id) ON DELETE RESTRICT,
  submitted_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id), district_id UUID REFERENCES districts(id),
  status submission_status NOT NULL DEFAULT 'draft',
  data JSONB NOT NULL DEFAULT '{}',
  gps_lat DOUBLE PRECISION, gps_lng DOUBLE PRECISION, gps_accuracy DOUBLE PRECISION,
  location GEOMETRY(Point, 4326),
  photos TEXT[] DEFAULT ARRAY[]::TEXT[], notes TEXT,
  reviewed_by UUID REFERENCES profiles(id), reviewed_at TIMESTAMPTZ, review_notes TEXT,
  submitted_at TIMESTAMPTZ, device_id TEXT, app_version TEXT,
  is_offline BOOLEAN NOT NULL DEFAULT false, offline_id TEXT, synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ,
  CONSTRAINT form_submissions_data_check CHECK (jsonb_typeof(data) = 'object'),
  CONSTRAINT form_submissions_gps_check CHECK (
    (gps_lat IS NULL AND gps_lng IS NULL) OR
    (gps_lat BETWEEN -90 AND 90 AND gps_lng BETWEEN -180 AND 180)
  )
);

-- supply_shortages
CREATE TABLE IF NOT EXISTS supply_shortages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID REFERENCES form_submissions(id),
  reported_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id), district_id UUID REFERENCES districts(id),
  item_name TEXT NOT NULL, item_category TEXT,
  quantity_needed INTEGER, quantity_available INTEGER DEFAULT 0, unit TEXT DEFAULT 'unit',
  severity shortage_severity NOT NULL DEFAULT 'medium',
  location GEOMETRY(Point, 4326), notes TEXT,
  is_resolved BOOLEAN NOT NULL DEFAULT false, resolved_at TIMESTAMPTZ, resolved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ
);

-- audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  action audit_action NOT NULL, table_name TEXT NOT NULL, record_id UUID,
  old_data JSONB, new_data JSONB,
  ip_address INET, user_agent TEXT, device_id TEXT, session_id TEXT,
  metadata JSONB DEFAULT '{}', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- health_facilities
CREATE TABLE IF NOT EXISTS health_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  district_id UUID NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
  facility_type TEXT, is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ
);

-- doc_references
CREATE TABLE IF NOT EXISTS doc_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar TEXT NOT NULL, description_ar TEXT, file_url TEXT,
  category TEXT DEFAULT 'general', is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ
);

-- pages (dynamic admin pages)
CREATE TABLE IF NOT EXISTS pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE, title_ar TEXT NOT NULL,
  content_ar JSONB NOT NULL DEFAULT '{}', icon TEXT,
  show_in_nav BOOLEAN DEFAULT false, nav_order INTEGER DEFAULT 99,
  roles TEXT[] DEFAULT ARRAY['admin'], is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- app_settings
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY, value JSONB NOT NULL,
  label_ar TEXT, type TEXT DEFAULT 'string', category TEXT DEFAULT 'general',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- rate_limits
CREATE TABLE IF NOT EXISTS rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL, window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_count INTEGER NOT NULL DEFAULT 1,
  UNIQUE(user_id, endpoint, window_start)
);

-- notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL, body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info', category TEXT DEFAULT 'general',
  data JSONB DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT false, read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- backup_history
CREATE TABLE IF NOT EXISTS backup_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backup_type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
  file_path TEXT, file_size_bytes BIGINT, tables_included TEXT[], record_count INTEGER,
  started_at TIMESTAMPTZ DEFAULT now(), completed_at TIMESTAMPTZ, error_message TEXT,
  created_by UUID REFERENCES profiles(id)
);

-- ============================================================
-- 4. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_governorates_code ON governorates(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_governorates_geom ON governorates USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_districts_governorate ON districts(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_code ON districts(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_geom ON districts USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_governorate ON profiles(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_district ON profiles(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_forms_active ON forms(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_forms_schema ON forms USING GIN(schema);
CREATE INDEX IF NOT EXISTS idx_submissions_form ON form_submissions(form_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_user ON form_submissions(submitted_by) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_gov ON form_submissions(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_district ON form_submissions(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_location ON form_submissions USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_submissions_created ON form_submissions(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_data ON form_submissions USING GIN(data);
CREATE INDEX IF NOT EXISTS idx_submissions_offline ON form_submissions(offline_id) WHERE offline_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_submission_offline_unique ON form_submissions(submitted_by, offline_id) WHERE offline_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_form_status_date ON form_submissions(form_id, status, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_gov ON supply_shortages(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_severity ON supply_shortages(severity) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_resolved ON supply_shortages(is_resolved) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_location ON supply_shortages USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_facilities_district ON health_facilities(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_references_category ON doc_references(category) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread ON notifications(recipient_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forms_title_search ON forms USING gin(to_tsvector('arabic', coalesce(title_ar,'') || ' ' || coalesce(title_en,'')));

-- ============================================================
-- 5. HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

CREATE OR REPLACE FUNCTION public.user_governorate_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

CREATE OR REPLACE FUNCTION public.user_district_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

CREATE OR REPLACE FUNCTION public.get_user_context()
RETURNS TABLE(user_id UUID, role user_role, governorate_id UUID, district_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT id, role, governorate_id, district_id FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

CREATE OR REPLACE FUNCTION public.check_role_hierarchy(target_role user_role, assigner_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $$
DECLARE assigner_role user_role;
  hierarchy JSONB := '{"admin":5,"central":4,"governorate":3,"district":2,"data_entry":1}';
BEGIN
  SELECT role INTO assigner_role FROM profiles WHERE id = assigner_id;
  IF assigner_role IS NULL THEN RETURN false; END IF;
  RETURN (hierarchy->>assigner_role::TEXT)::INT > (hierarchy->>target_role::TEXT)::INT;
END; $$;

-- Rate limit function
CREATE OR REPLACE FUNCTION public.check_and_increment_rate_limit(
  p_user_id UUID, p_endpoint TEXT, p_window_seconds INTEGER DEFAULT 60, p_max_requests INTEGER DEFAULT 10
) RETURNS TABLE(allowed BOOLEAN, current_count INTEGER, reset_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_window_start TIMESTAMPTZ; v_current_count INTEGER;
BEGIN
  v_window_start := date_trunc('second', now()) -
    (EXTRACT(EPOCH FROM (date_trunc('second', now()) - 'epoch'::TIMESTAMPTZ))::INTEGER % p_window_seconds) * INTERVAL '1 second';
  INSERT INTO rate_limits (user_id, endpoint, window_start, request_count)
  VALUES (p_user_id, p_endpoint, v_window_start, 1)
  ON CONFLICT (user_id, endpoint, window_start)
  DO UPDATE SET request_count = rate_limits.request_count + 1
  RETURNING request_count INTO v_current_count;
  RETURN QUERY SELECT v_current_count <= p_max_requests AS allowed, v_current_count AS current_count,
    v_window_start + (p_window_seconds || ' seconds')::INTERVAL AS reset_at;
END; $$;

CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limits()
RETURNS void LANGUAGE sql SECURITY DEFINER
AS $$ DELETE FROM rate_limits WHERE window_start < now() - INTERVAL '2 hours'; $$;

-- ============================================================
-- 6. TRIGGER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_audit_log() RETURNS TRIGGER AS $$
DECLARE old_json JSONB; new_json JSONB;
BEGIN
  IF TG_OP = 'DELETE' THEN
    old_json = to_jsonb(OLD);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data)
    VALUES (auth.uid(), 'delete', TG_TABLE_NAME, OLD.id, old_json);
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    old_json = to_jsonb(OLD); new_json = to_jsonb(NEW);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data, new_data)
    VALUES (auth.uid(), 'update', TG_TABLE_NAME, NEW.id, old_json, new_json);
    RETURN NEW;
  ELSIF TG_OP = 'INSERT' THEN
    new_json = to_jsonb(NEW);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'create', TG_TABLE_NAME, NEW.id, new_json);
    RETURN NEW;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION set_submission_location() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.gps_lat IS NOT NULL AND NEW.gps_lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.gps_lng, NEW.gps_lat), 4326);
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role, governorate_id, district_id)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'data_entry'),
    (NEW.raw_user_meta_data->>'governorate_id')::UUID,
    (NEW.raw_user_meta_data->>'district_id')::UUID);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END; $$;

-- Notify on new submission
CREATE OR REPLACE FUNCTION notify_on_submission() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO notifications (recipient_id, title, body, type, category, data)
  SELECT p.id, 'استمارة جديدة',
    'تم تقديم استمارة جديدة في ' || COALESCE((SELECT name_ar FROM governorates WHERE id = NEW.governorate_id), 'غير محدد'),
    'info', 'form', json_build_object('submission_id', NEW.id, 'form_id', NEW.form_id)
  FROM profiles p
  WHERE p.is_active = true AND p.deleted_at IS NULL AND p.id != NEW.submitted_by
    AND (p.role IN ('admin','central') OR (p.role = 'governorate' AND p.governorate_id = NEW.governorate_id));
  RETURN NEW;
END; $$;

-- Notify on status change
CREATE OR REPLACE FUNCTION notify_on_status_change() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_label TEXT; v_type TEXT;
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;
  CASE NEW.status
    WHEN 'approved' THEN v_label := 'تمت الموافقة'; v_type := 'success';
    WHEN 'rejected' THEN v_label := 'تم الرفض'; v_type := 'error';
    WHEN 'reviewed' THEN v_label := 'تمت المراجعة'; v_type := 'info';
    ELSE RETURN NEW;
  END CASE;
  INSERT INTO notifications (recipient_id, title, body, type, category, data)
  VALUES (NEW.submitted_by, 'تحديث حالة الاستمارة',
    'تم ' || v_label || ' على استمارتك' || CASE WHEN NEW.review_notes IS NOT NULL THEN ': ' || NEW.review_notes ELSE '' END,
    v_type, 'form', json_build_object('submission_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status));
  RETURN NEW;
END; $$;

-- ============================================================
-- 7. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_shortages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE doc_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE backup_history ENABLE ROW LEVEL SECURITY;

-- PROFILES
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_central" ON profiles;
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;

CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_insert_admin" ON profiles FOR INSERT WITH CHECK (public.user_role() = 'admin');
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (public.user_role() IN ('admin','central'));
CREATE POLICY "profiles_select_governorate" ON profiles FOR SELECT USING (public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id());
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (public.user_role() = 'admin');
CREATE POLICY "profiles_delete_admin" ON profiles FOR DELETE USING (public.user_role() = 'admin');

-- GOVERNORATES
DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
DROP POLICY IF EXISTS "governorates_modify_admin" ON governorates;
CREATE POLICY "governorates_select_all" ON governorates FOR SELECT USING (true);
CREATE POLICY "governorates_modify_admin" ON governorates FOR ALL USING (public.user_role() = 'admin');

-- DISTRICTS
DROP POLICY IF EXISTS "districts_select_all" ON districts;
DROP POLICY IF EXISTS "districts_modify_admin" ON districts;
CREATE POLICY "districts_select_all" ON districts FOR SELECT USING (true);
CREATE POLICY "districts_modify_admin" ON districts FOR ALL USING (public.user_role() = 'admin');

-- FORMS
DROP POLICY IF EXISTS "forms_select_all" ON forms;
DROP POLICY IF EXISTS "forms_modify_admin" ON forms;
CREATE POLICY "forms_select_all" ON forms FOR SELECT USING (is_active = true OR public.user_role() = 'admin');
CREATE POLICY "forms_modify_admin" ON forms FOR ALL USING (public.user_role() IN ('admin','central'));

-- FORM SUBMISSIONS
DROP POLICY IF EXISTS "submissions_insert_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_hierarchical" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_own_or_admin" ON form_submissions;

CREATE POLICY "submissions_insert_own" ON form_submissions FOR INSERT WITH CHECK (submitted_by = auth.uid());
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
CREATE POLICY "submissions_update_own_or_admin" ON form_submissions FOR UPDATE USING (
  submitted_by = auth.uid() OR public.user_role() IN ('admin','central')
);

-- SUPPLY SHORTAGES
DROP POLICY IF EXISTS "shortages_select_hierarchical" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_insert_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_update_hierarchical" ON supply_shortages;
CREATE POLICY "shortages_select_hierarchical" ON supply_shortages FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true WHEN 'central' THEN true
    WHEN 'governorate' THEN governorate_id = public.user_governorate_id()
    WHEN 'district' THEN district_id = public.user_district_id()
    ELSE reported_by = auth.uid()
  END
);
CREATE POLICY "shortages_insert_auth" ON supply_shortages FOR INSERT WITH CHECK (reported_by = auth.uid());
CREATE POLICY "shortages_update_hierarchical" ON supply_shortages FOR UPDATE USING (reported_by = auth.uid() OR public.user_role() IN ('admin','central'));

-- HEALTH FACILITIES
DROP POLICY IF EXISTS "facilities_select_all" ON health_facilities;
CREATE POLICY "facilities_select_all" ON health_facilities FOR SELECT USING (true);

-- AUDIT LOGS
DROP POLICY IF EXISTS "audit_select_admin" ON audit_logs;
DROP POLICY IF EXISTS "audit_insert_system" ON audit_logs;
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT USING (public.user_role() IN ('admin','central'));
CREATE POLICY "audit_insert_system" ON audit_logs FOR INSERT WITH CHECK (true);

-- DOC REFERENCES
DROP POLICY IF EXISTS "references_select_active" ON doc_references;
DROP POLICY IF EXISTS "references_manage_admin" ON doc_references;
CREATE POLICY "references_select_active" ON doc_references FOR SELECT USING (is_active = true AND deleted_at IS NULL);
CREATE POLICY "references_manage_admin" ON doc_references FOR ALL USING (public.user_role() = 'admin');

-- PAGES
DROP POLICY IF EXISTS "pages_select_active" ON pages;
DROP POLICY IF EXISTS "pages_manage_admin" ON pages;
CREATE POLICY "pages_select_active" ON pages FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
CREATE POLICY "pages_manage_admin" ON pages FOR ALL USING (public.user_role() IN ('admin','central'));

-- APP SETTINGS
DROP POLICY IF EXISTS "settings_select_auth" ON app_settings;
DROP POLICY IF EXISTS "settings_manage_admin" ON app_settings;
CREATE POLICY "settings_select_auth" ON app_settings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "settings_manage_admin" ON app_settings FOR ALL USING (public.user_role() = 'admin');

-- RATE LIMITS (system only)
DROP POLICY IF EXISTS "rate_limits_system_only" ON rate_limits;
CREATE POLICY "rate_limits_system_only" ON rate_limits FOR ALL USING (false);

-- NOTIFICATIONS
DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
DROP POLICY IF EXISTS "notifications_insert_system" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications FOR SELECT USING (recipient_id = auth.uid());
CREATE POLICY "notifications_update_own" ON notifications FOR UPDATE USING (recipient_id = auth.uid());
CREATE POLICY "notifications_insert_system" ON notifications FOR INSERT WITH CHECK (true);

-- BACKUP HISTORY
DROP POLICY IF EXISTS "backup_admin_only" ON backup_history;
CREATE POLICY "backup_admin_only" ON backup_history FOR ALL USING (public.user_role() = 'admin');

-- ============================================================
-- 8. STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('submission-photos','submission-photos',false,10485760,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars','avatars',true,2097152,ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('references','references',false,52428800,ARRAY['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Users can upload own submission photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own submission photos" ON storage.objects;
DROP POLICY IF EXISTS "Admins can upload references" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can view references" ON storage.objects;
CREATE POLICY "Users can upload own submission photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'submission-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can view own submission photos" ON storage.objects FOR SELECT USING (bucket_id = 'submission-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Admins can upload references" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'references' AND public.user_role() = 'admin');
CREATE POLICY "Authenticated can view references" ON storage.objects FOR SELECT USING (bucket_id = 'references' AND auth.uid() IS NOT NULL);

-- ============================================================
-- 9. GRANTS
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
GRANT SELECT ON notifications TO authenticated;
GRANT INSERT ON profiles TO anon;

-- ============================================================
-- 10. APPLY TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS trg_profiles_updated ON profiles;
DROP TRIGGER IF EXISTS trg_governorates_updated ON governorates;
DROP TRIGGER IF EXISTS trg_districts_updated ON districts;
DROP TRIGGER IF EXISTS trg_forms_updated ON forms;
DROP TRIGGER IF EXISTS trg_submissions_updated ON form_submissions;
DROP TRIGGER IF EXISTS trg_shortages_updated ON supply_shortages;
DROP TRIGGER IF EXISTS trg_profiles_audit ON profiles;
DROP TRIGGER IF EXISTS trg_forms_audit ON forms;
DROP TRIGGER IF EXISTS trg_submissions_audit ON form_submissions;
DROP TRIGGER IF EXISTS trg_shortages_audit ON supply_shortages;
DROP TRIGGER IF EXISTS trg_submission_location ON form_submissions;
DROP TRIGGER IF EXISTS trg_auth_signup ON auth.users;
DROP TRIGGER IF EXISTS trigger_notify_submission ON form_submissions;
DROP TRIGGER IF EXISTS trigger_notify_status_change ON form_submissions;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_governorates_updated BEFORE UPDATE ON governorates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_districts_updated BEFORE UPDATE ON districts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_forms_updated BEFORE UPDATE ON forms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_submissions_updated BEFORE UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_shortages_updated BEFORE UPDATE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_profiles_audit AFTER INSERT OR UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_forms_audit AFTER INSERT OR UPDATE OR DELETE ON forms FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_submissions_audit AFTER INSERT OR UPDATE OR DELETE ON form_submissions FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_shortages_audit AFTER INSERT OR UPDATE OR DELETE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION create_audit_log();

CREATE TRIGGER trg_submission_location BEFORE INSERT OR UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION set_submission_location();
CREATE TRIGGER trg_auth_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
CREATE TRIGGER trigger_notify_submission AFTER INSERT ON form_submissions FOR EACH ROW EXECUTE FUNCTION notify_on_submission();
CREATE TRIGGER trigger_notify_status_change AFTER UPDATE OF status ON form_submissions FOR EACH ROW EXECUTE FUNCTION notify_on_status_change();

-- ============================================================
-- 11. DEFAULT SETTINGS
-- ============================================================
INSERT INTO app_settings (key, value, label_ar, type, category) VALUES
  ('app_name_ar', '"منصة مشرف EPI"', 'اسم التطبيق', 'string', 'branding'),
  ('primary_color', '"#1565C0"', 'اللون الرئيسي', 'color', 'branding'),
  ('offline_days', '30', 'أيام الاحتفاظ المحلي', 'number', 'offline'),
  ('ai_model', '"local"', 'نموذج الذكاء الاصطناعي', 'string', 'ai'),
  ('auto_sync_interval', '5', 'فترة المزامنة التلقائية (دقائق)', 'number', 'sync'),
  ('notification_enabled', 'true', 'تفعيل الإشعارات', 'boolean', 'notifications'),
  ('max_photo_size_mb', '10', 'أقصى حجم للصورة بالميجا', 'number', 'uploads'),
  ('max_photos_per_submission', '5', 'أقصى عدد صور لكل إرسال', 'number', 'uploads'),
  ('auto_approve_forms', 'false', 'القبول التلقائي للنماذج', 'boolean', 'workflow'),
  ('session_timeout_minutes', '480', 'مهلة انتهاء الجلسة بالدقائق', 'number', 'security'),
  ('max_login_attempts', '5', 'أقصى عدد محاولات تسجيل الدخول', 'number', 'security')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 13. CLEANUP: Soft-delete unwanted forms
-- ============================================================
UPDATE forms
SET deleted_at = now(), updated_at = now()
WHERE deleted_at IS NULL
  AND (
    title_ar IN (
      'استمارة مراقبة التطعيم',
      'تقرير الزيارات الميدانية',
      'تقرير نقص التجهيزات'
    )
    OR title_en IN (
      'Vaccination Monitoring Form',
      'Field Visit Report',
      'Equipment Shortage Report'
    )
  );

COMMIT;

-- ============================================================
-- 12. SEED DATA
-- ============================================================
-- (See migrations/002_seed_data.sql for full seed data)
