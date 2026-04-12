-- ============================================================
-- EPI Supervisor Platform — Complete Database Schema
-- Version: 2.0.0 (Supabase-compatible, fixed)
-- ============================================================
-- شغّل هذا الملف في Supabase SQL Editor
-- Run this file in Supabase SQL Editor
-- ============================================================

BEGIN;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
-- Supabase provides these in the `extensions` schema by default.
-- Use IF NOT EXISTS to avoid errors if already enabled.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- PostGIS: required for GEOMETRY columns. Supabase usually has this pre-enabled.
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================
-- 2. ENUMS
-- ============================================================

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'admin', 'central', 'governorate', 'district', 'data_entry'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE submission_status AS ENUM (
    'draft', 'submitted', 'reviewed', 'approved', 'rejected'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE shortage_severity AS ENUM (
    'critical', 'high', 'medium', 'low'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE audit_action AS ENUM (
    'create', 'read', 'update', 'delete',
    'login', 'logout', 'submit', 'approve', 'reject', 'export'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 3. TABLES
-- ============================================================

-- ----- governorates -----
CREATE TABLE IF NOT EXISTS governorates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  geometry GEOMETRY(MultiPolygon, 4326),
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT governorates_code_check CHECK (length(code) >= 2)
);

-- ----- districts -----
CREATE TABLE IF NOT EXISTS districts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  governorate_id UUID NOT NULL REFERENCES governorates(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  geometry GEOMETRY(MultiPolygon, 4326),
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT districts_code_check CHECK (length(code) >= 2)
);

-- ----- profiles -----
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'data_entry',
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT profiles_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT profiles_full_name_check CHECK (length(full_name) >= 2)
);

-- ----- forms -----
CREATE TABLE IF NOT EXISTS forms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  description_ar TEXT,
  description_en TEXT,
  schema JSONB NOT NULL DEFAULT '{}',
  version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  requires_gps BOOLEAN NOT NULL DEFAULT false,
  requires_photo BOOLEAN NOT NULL DEFAULT false,
  max_photos INTEGER DEFAULT 5,
  allowed_roles user_role[] NOT NULL DEFAULT ARRAY['data_entry','district','governorate','central','admin']::user_role[],
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT forms_schema_check CHECK (jsonb_typeof(schema) = 'object'),
  CONSTRAINT forms_title_check CHECK (length(title_ar) >= 2)
);

-- ----- form_submissions -----
CREATE TABLE IF NOT EXISTS form_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  form_id UUID NOT NULL REFERENCES forms(id) ON DELETE RESTRICT,
  submitted_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  status submission_status NOT NULL DEFAULT 'draft',
  data JSONB NOT NULL DEFAULT '{}',
  gps_lat DOUBLE PRECISION,
  gps_lng DOUBLE PRECISION,
  gps_accuracy DOUBLE PRECISION,
  location GEOMETRY(Point, 4326),
  photos TEXT[] DEFAULT ARRAY[]::TEXT[],
  notes TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  submitted_at TIMESTAMPTZ,
  device_id TEXT,
  app_version TEXT,
  is_offline BOOLEAN NOT NULL DEFAULT false,
  offline_id TEXT,
  synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT form_submissions_data_check CHECK (jsonb_typeof(data) = 'object'),
  CONSTRAINT form_submissions_gps_check CHECK (
    (gps_lat IS NULL AND gps_lng IS NULL) OR
    (gps_lat BETWEEN -90 AND 90 AND gps_lng BETWEEN -180 AND 180)
  )
);

-- ----- supply_shortages -----
CREATE TABLE IF NOT EXISTS supply_shortages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  submission_id UUID REFERENCES form_submissions(id),
  reported_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  item_name TEXT NOT NULL,
  item_category TEXT,
  quantity_needed INTEGER,
  quantity_available INTEGER DEFAULT 0,
  unit TEXT DEFAULT 'unit',
  severity shortage_severity NOT NULL DEFAULT 'medium',
  location GEOMETRY(Point, 4326),
  notes TEXT,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- ----- audit_logs -----
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  action audit_action NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  device_id TEXT,
  session_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. INDEXES
-- ============================================================

-- governorates
CREATE INDEX IF NOT EXISTS idx_governorates_code ON governorates(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_governorates_geom ON governorates USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_governorates_name_ar ON governorates USING gin(name_ar gin_trgm_ops);

-- districts
CREATE INDEX IF NOT EXISTS idx_districts_governorate ON districts(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_code ON districts(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_geom ON districts USING GIST(geometry);

-- profiles
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_governorate ON profiles(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_district ON profiles(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_active ON profiles(is_active) WHERE deleted_at IS NULL;

-- forms
CREATE INDEX IF NOT EXISTS idx_forms_active ON forms(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_forms_created_by ON forms(created_by);
CREATE INDEX IF NOT EXISTS idx_forms_schema ON forms USING GIN(schema);

-- form_submissions
CREATE INDEX IF NOT EXISTS idx_submissions_form ON form_submissions(form_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_by ON form_submissions(submitted_by) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_governorate ON form_submissions(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_district ON form_submissions(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_location ON form_submissions USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_submissions_created ON form_submissions(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_data ON form_submissions USING GIN(data);
CREATE INDEX IF NOT EXISTS idx_submissions_offline ON form_submissions(offline_id) WHERE offline_id IS NOT NULL;

-- supply_shortages
CREATE INDEX IF NOT EXISTS idx_shortages_governorate ON supply_shortages(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_district ON supply_shortages(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_severity ON supply_shortages(severity) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_resolved ON supply_shortages(is_resolved) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_location ON supply_shortages USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_shortages_item ON supply_shortages USING gin(item_name gin_trgm_ops);

-- audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_logs(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_logs(session_id);

-- ============================================================
-- 5. HELPER FUNCTIONS (public schema — NOT auth schema)
-- ============================================================
-- ⚠️ Supabase لا يسمح بإنشاء دوال في schema auth
-- Supabase does NOT allow creating functions in auth schema

-- Get current user role
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- Get current user governorate
CREATE OR REPLACE FUNCTION public.user_governorate_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- Get current user district
CREATE OR REPLACE FUNCTION public.user_district_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- Role hierarchy check
CREATE OR REPLACE FUNCTION public.check_role_hierarchy(target_role user_role, assigner_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  assigner_role user_role;
  hierarchy JSONB := '{"admin":5,"central":4,"governorate":3,"district":2,"data_entry":1}';
BEGIN
  SELECT role INTO assigner_role FROM profiles WHERE id = assigner_id;
  IF assigner_role IS NULL THEN RETURN false; END IF;
  RETURN (hierarchy->>assigner_role::TEXT)::INT > (hierarchy->>target_role::TEXT)::INT;
END;
$$;

-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_shortages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop old policies if re-running
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_central" ON profiles;
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;

DROP POLICY IF EXISTS "governorates_select_all" ON governorates;
DROP POLICY IF EXISTS "governorates_modify_admin" ON governorates;

DROP POLICY IF EXISTS "districts_select_all" ON districts;
DROP POLICY IF EXISTS "districts_modify_admin" ON districts;

DROP POLICY IF EXISTS "forms_select_all" ON forms;
DROP POLICY IF EXISTS "forms_select_admin" ON forms;
DROP POLICY IF EXISTS "forms_modify_admin" ON forms;

DROP POLICY IF EXISTS "submissions_select_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_district" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_governorate" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_central_admin" ON form_submissions;
DROP POLICY IF EXISTS "submissions_insert_own" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_own_draft" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_reviewer" ON form_submissions;

DROP POLICY IF EXISTS "shortages_select_all_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_insert_auth" ON supply_shortages;
DROP POLICY IF EXISTS "shortages_update_hierarchy" ON supply_shortages;

DROP POLICY IF EXISTS "audit_select_admin" ON audit_logs;
DROP POLICY IF EXISTS "audit_select_central" ON audit_logs;
DROP POLICY IF EXISTS "audit_insert_system" ON audit_logs;

-- ---- PROFILES ----
-- ⚠️ أهم policy: السماح للمستخدم الجديد ي_INSERT_صفحته
-- Critical: allow new user to INSERT their own profile during signup

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

-- ---- GOVERNORATES ----

CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "governorates_modify_admin" ON governorates
  FOR ALL USING (public.user_role() = 'admin');

-- ---- DISTRICTS ----

CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "districts_modify_admin" ON districts
  FOR ALL USING (public.user_role() = 'admin');

-- ---- FORMS ----

CREATE POLICY "forms_select_all" ON forms
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "forms_select_admin" ON forms
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "forms_modify_admin" ON forms
  FOR ALL USING (public.user_role() = 'admin');

-- ---- FORM_SUBMISSIONS ----

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

-- ---- SUPPLY_SHORTAGES ----

CREATE POLICY "shortages_select_all_auth" ON supply_shortages
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "shortages_insert_auth" ON supply_shortages
  FOR INSERT WITH CHECK (reported_by = auth.uid());

CREATE POLICY "shortages_update_hierarchy" ON supply_shortages
  FOR UPDATE USING (
    reported_by = auth.uid() OR
    public.user_role() IN ('district', 'governorate', 'central', 'admin')
  );

-- ---- AUDIT_LOGS ----

CREATE POLICY "audit_select_admin" ON audit_logs
  FOR SELECT USING (public.user_role() = 'admin');

CREATE POLICY "audit_select_central" ON audit_logs
  FOR SELECT USING (public.user_role() = 'central');

-- SECURITY DEFINER function يتجاوز RLS → السماح بالـ INSERT
CREATE POLICY "audit_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- لا تحديث أو حذف على audit logs (immutable)

-- ============================================================
-- 7. TRIGGER FUNCTIONS
-- ============================================================

-- Auto updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Audit log (SECURITY DEFINER → يتجاوز RLS)
CREATE OR REPLACE FUNCTION create_audit_log()
RETURNS TRIGGER AS $$
DECLARE
  old_json JSONB;
  new_json JSONB;
BEGIN
  IF TG_OP = 'DELETE' THEN
    old_json = to_jsonb(OLD);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data)
    VALUES (auth.uid(), 'delete', TG_TABLE_NAME, OLD.id, old_json);
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    old_json = to_jsonb(OLD);
    new_json = to_jsonb(NEW);
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-set location from GPS
CREATE OR REPLACE FUNCTION set_submission_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.gps_lat IS NOT NULL AND NEW.gps_lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.gps_lng, NEW.gps_lat), 4326);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auto-create profile on signup
-- ⚠️ SECURITY DEFINER → يتجاوز RLS على profiles
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'data_entry')
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- لا تفشل الـ signup لو فشل إنشاء الـ profile
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 8. APPLY TRIGGERS
-- ============================================================

-- Drop existing triggers if re-running
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

-- Updated_at triggers
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_governorates_updated BEFORE UPDATE ON governorates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_districts_updated BEFORE UPDATE ON districts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_forms_updated BEFORE UPDATE ON forms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_submissions_updated BEFORE UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_shortages_updated BEFORE UPDATE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Audit triggers
CREATE TRIGGER trg_profiles_audit AFTER INSERT OR UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_forms_audit AFTER INSERT OR UPDATE OR DELETE ON forms FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_submissions_audit AFTER INSERT OR UPDATE OR DELETE ON form_submissions FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_shortages_audit AFTER INSERT OR UPDATE OR DELETE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Location trigger
CREATE TRIGGER trg_submission_location BEFORE INSERT OR UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION set_submission_location();

-- Signup trigger
CREATE TRIGGER trg_auth_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 9. COMMENTS
-- ============================================================

COMMENT ON TABLE governorates IS 'Administrative governorate divisions (محافظات)';
COMMENT ON TABLE districts IS 'Administrative district divisions within governorates (مديريات)';
COMMENT ON TABLE profiles IS 'User profiles with role-based access control';
COMMENT ON TABLE forms IS 'Dynamic form definitions with JSON schema';
COMMENT ON TABLE form_submissions IS 'Form submission data with offline sync support';
COMMENT ON TABLE supply_shortages IS 'Supply shortage tracking with geo-location';
COMMENT ON TABLE audit_logs IS 'Immutable audit trail for all system actions';

COMMIT;
-- ============================================================
-- EPI Supervisor Platform — SIA Forms (النشاط الايصالي التكاملي)
-- Version: 2.0.0
-- ============================================================

BEGIN;

-- Clean duplicates on re-run
DELETE FROM forms WHERE title_ar IN (
  'استمارة الاشراف للنشاط الايصالي التكاملي',
  'استمارة الجاهزية للنشاط الايصالي التكاملي'
) AND deleted_at IS NULL;

-- ============================================================
-- FORM 1: استمارة الاشراف للنشاط الايصالي التكاملي
-- Supervision Form for Integrated SIA
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة الاشراف للنشاط الايصالي التكاملي',
  'Integrated SIA Supervision Form',
  'استمارة شاملة للإشراف الميداني على فرق النشاط الايصالي التكاملي',
  'Comprehensive field supervision form for integrated supplementary immunization activity teams',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "health_facility", "type": "text", "label_ar": "المرفق الصحي التابع للفريق", "required": true},
          {"key": "village_name", "type": "text", "label_ar": "اسم القرية التي يعمل بها الفريق", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true},
          {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true}
        ]
      },
      {
        "id": "team_info",
        "title_ar": "معلومات الفريق",
        "order": 2,
        "fields": [
          {"key": "team_members", "type": "textarea", "label_ar": "أسماء أعضاء الفريق", "required": true},
          {"key": "has_activity_plan", "type": "yesno", "label_ar": "هل لدى الفريق خطة وخارطة تبين القرى المستهدفة حسب خط سير الفريق أيام النشاط؟", "required": true},
          {"key": "active_members_count", "type": "number", "label_ar": "أعضاء الفريق العاملين", "required": true},
          {"key": "has_doctor_or_trained", "type": "yesno", "label_ar": "هل أحد أعضاء الفريق طبيب؟ أو فني مدرب على الرعاية التكاملية", "required": true},
          {"key": "wearing_uniform", "type": "yesno", "label_ar": "هل يلتزم أعضاء الفريق بلبس الزي (البالطو)؟", "required": true}
        ]
      },
      {
        "id": "work_environment",
        "title_ar": "بيئة العمل والتنسيق",
        "order": 3,
        "fields": [
          {"key": "suitable_location", "type": "yesno", "label_ar": "هل المكان المختار لتنفيذ الجلسة مناسب ويضمن الخصوصية للنساء؟", "required": true},
          {"key": "community_coordination", "type": "yesno", "label_ar": "هل تم التنسيق المسبق مع المجتمع (تأكد من ذلك في القرية)؟", "required": true},
          {"key": "has_speaker", "type": "yesno", "label_ar": "هل يتوفر مع الفريق مكبر صوت؟", "required": true},
          {"key": "has_transport", "type": "yesno", "label_ar": "هل توجد وسيلة نقل مناسبة لدى الفريق؟", "required": true},
          {"key": "previous_visit", "type": "yesno", "label_ar": "هل تمت زيارة الفريق من قبل المستوى الأعلى ومدونة بسجل الإشراف؟", "required": true}
        ]
      },
      {
        "id": "records_and_docs",
        "title_ar": "السجلات والوثائق",
        "order": 4,
        "fields": [
          {"key": "complete_records", "type": "yesno", "label_ar": "هل تتوفر لدى الفريق سجلات مكتملة بحسب الخدمة؟", "required": true},
          {"key": "daily_work_forms", "type": "yesno", "label_ar": "هل توجد استمارات العمل اليومي حسب الخدمة المقدمة؟", "required": true},
          {"key": "correct_data_entry", "type": "yesno", "label_ar": "هل يتم تدوين البيانات بشكل صحيح وفي المكان المناسب بحسب نوع الخدمة؟", "required": true},
          {"key": "next_visit_noted", "type": "yesno", "label_ar": "هل يتم تدوين العودة للزيارة القادمة؟", "required": true}
        ]
      },
      {
        "id": "vaccination_cards",
        "title_ar": "بطاقات التحصين",
        "order": 5,
        "fields": [
          {"key": "child_vaccination_cards", "type": "yesno", "label_ar": "هل يتم صرف بطاقة تحصين للأطفال المستهدفين للتحصين؟", "required": true},
          {"key": "women_vaccination_cards", "type": "yesno", "label_ar": "هل يتم صرف بطاقة تحصين للنساء المستهدفات للتحصين؟", "required": true}
        ]
      },
      {
        "id": "service_quality",
        "title_ar": "جودة الخدمة",
        "order": 6,
        "fields": [
          {"key": "good_acceptance", "type": "yesno", "label_ar": "هل يوجد إقبال جيد على الخدمة من قبل المستفيدين؟", "required": true},
          {"key": "safe_vaccination", "type": "yesno", "label_ar": "هل يتم ممارسة التطعيم الآمن بشكل صحيح من قبل الفريق؟", "required": true},
          {"key": "respiratory_rate_check", "type": "yesno", "label_ar": "هل يتم احتساب سرعة التنفس للأطفال الذين يعانون من سعال؟", "required": true},
          {"key": "muac_measurement", "type": "yesno", "label_ar": "هل يتم قياس محيط منتصف الذراع للأطفال والنساء بشكل صحيح؟", "required": true},
          {"key": "ors_provision", "type": "yesno", "label_ar": "هل يتم إعطاء محلول الإرواء لكل الأطفال الذين يعانون من إسهال؟", "required": true},
          {"key": "clean_delivery_kit", "type": "yesno", "label_ar": "هل يتم تزويد جميع النساء الحوامل في الشهرين الأخيرين من الحمل بعلبة الولادة النظيفة؟", "required": true},
          {"key": "nutrition_assessment", "type": "yesno", "label_ar": "هل يقوم العامل بتقييم مشاكل التغذية؟", "required": true}
        ]
      },
      {
        "id": "vitamins_and_referral",
        "title_ar": "الفيتامينات والإحالة",
        "order": 7,
        "fields": [
          {"key": "vitamin_a_children", "type": "yesno", "label_ar": "هل يعطي فيتامين (أ) وفق البروتوكول المعتمد للأطفال؟", "required": true},
          {"key": "vitamin_a_women", "type": "yesno", "label_ar": "هل يعطي فيتامين (أ) وفق البروتوكول المعتمد للنساء؟", "required": true},
          {"key": "facility_referral", "type": "yesno", "label_ar": "هل يتم الإحالة للمرفق الصحي؟", "required": true},
          {"key": "correct_medication", "type": "yesno", "label_ar": "هل يتم إعطاء الأدوية بطريقة سليمة ومرشدة؟", "required": true},
          {"key": "nutrition_counseling", "type": "yesno", "label_ar": "هل يقوم العامل الصحي بالنصح والإرشاد حول مشاكل التغذية؟", "required": true}
        ]
      },
      {
        "id": "vaccine_handling",
        "title_ar": "التعامل مع اللقاحات",
        "order": 8,
        "fields": [
          {"key": "vaccine_disposal", "type": "yesno", "label_ar": "هل يتم التخلص من اللقاحات الممزوجة في الفترة المحددة (بعد 6 ساعات من المزج)؟", "required": true},
          {"key": "safety_box_usage", "type": "yesno", "label_ar": "هل يتم استخدام صندوق الأمان بصورة صحيحة والتخلص منه بشكل سليم؟", "required": true},
          {"key": "cold_chain_proper", "type": "yesno", "label_ar": "هل اللقاحات الموجودة في حاملات الطعوم محفوظة بطريقة سليمة؟", "required": true}
        ]
      },
      {
        "id": "supplies_equipment",
        "title_ar": "الإمدادات والمعدات",
        "order": 9,
        "fields": [
          {"key": "family_planning_available", "type": "yesno", "label_ar": "هل توفر وسائل تنظيم الأسرة حسب الأصناف (حبوب مركبة، حبوب إحادية، رفال ذكري، حقن)؟", "required": true},
          {"key": "folic_iron_stock", "type": "yesno", "label_ar": "هل لدى الفريق إمداد كافي من حمض الفوليك والحديد؟", "required": true},
          {"key": "fetal_stethoscope", "type": "yesno", "label_ar": "هل توجد لدى الفريق سماعة جنين؟", "required": true},
          {"key": "bp_device", "type": "yesno", "label_ar": "هل يتوفر لدى الفريق سماعة فحص وجهاز ضغط الدم؟", "required": true},
          {"key": "muac_tape", "type": "yesno", "label_ar": "هل لدى الفريق أشرطة قياس محيط الذراع؟", "required": true},
          {"key": "height_board", "type": "yesno", "label_ar": "هل لدى الفريق أشرطة قياس الطول؟", "required": true},
          {"key": "thermometer", "type": "yesno", "label_ar": "هل لدى الفريق ترمومتر لقياس درجة حرارة الأطفال؟", "required": true},
          {"key": "scale", "type": "yesno", "label_ar": "هل يوجد مع الفريق ميزان؟", "required": true},
          {"key": "daily_supply_tracking", "type": "yesno", "label_ar": "هل يقوم الفريق بتدوين حركة الإمداد الوارد والمنصرف يومياً؟", "required": true}
        ]
      },
      {
        "id": "service_numbers",
        "title_ar": "أعداد المترددين",
        "order": 10,
        "fields": [
          {"key": "immunization_children", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين من الأطفال", "required": true},
          {"key": "immunization_women", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين من النساء", "required": true},
          {"key": "covid19_vaccination", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين بلقاح كوفيد 19", "required": true},
          {"key": "child_health_under2m", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل للأطفال دون الشهرين", "required": true},
          {"key": "child_health_2to59m", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل من 2 إلى 59 شهر", "required": true},
          {"key": "child_health_over5", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل للأطفال فوق الخامسة", "required": true},
          {"key": "fp_clients", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية بتنظيم الأسرة", "required": true},
          {"key": "anc_clients", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية رعاية حوامل", "required": true},
          {"key": "delivery_cases", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية ولادات", "required": true},
          {"key": "nutrition_children_6_59", "type": "number", "label_ar": "عدد المترددين لخدمة التغذية أطفال من 6-59 شهر", "required": true},
          {"key": "referred_children", "type": "number", "label_ar": "الأطفال الذين تم إحالتهم", "required": true},
          {"key": "nutrition_women", "type": "number", "label_ar": "عدد المترددين لخدمة التغذية نساء حوامل ومرضعات", "required": true}
        ]
      },
      {
        "id": "shortages",
        "title_ar": "العجز في الإمدادات",
        "order": 11,
        "fields": [
          {"key": "has_immunization_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة التحصين", "required": true},
          {"key": "immunization_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة التحصين"},
          {"key": "has_covid_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة لقاح كوفيد", "required": true},
          {"key": "covid_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة لقاح كوفيد"},
          {"key": "has_reproductive_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة الصحة الإنجابية", "required": true},
          {"key": "reproductive_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة الصحة الإنجابية"},
          {"key": "has_child_health_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة صحة الطفل", "required": true},
          {"key": "child_health_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة صحة الطفل"},
          {"key": "has_nutrition_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة التغذية", "required": true},
          {"key": "nutrition_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة التغذية"}
        ]
      },
      {
        "id": "follow_up",
        "title_ar": "المتابعة والتوصيات",
        "order": 12,
        "fields": [
          {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
          {"key": "actions_taken", "type": "textarea", "label_ar": "الإجراءات المتخذة", "required": true},
          {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
          {"key": "supervision_photo", "type": "photo", "label_ar": "صورة توثيقية للنزول الاشرافي"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      },
      {
        "id": "catch_up_policy",
        "title_ar": "سياسة الالتحاق بالركب",
        "order": 13,
        "fields": [
          {"key": "has_vaccine_carrier", "type": "yesno", "label_ar": "هل لدى المطعم حافظة لقاح مع قوالب ثلج مبردة؟", "required": true},
          {"key": "vaccines_sufficient", "type": "yesno", "label_ar": "هل اللقاحات والمستلزمات الأخرى متوفرة وكافية لجلسة التطعيم؟", "required": true},
          {"key": "correct_vaccine_site", "type": "yesno", "label_ar": "هل يتم إعطاء اللقاح في الموضع المناسب والصحيح؟", "required": true},
          {"key": "catch_up_knowledge", "type": "yesno", "label_ar": "هل لدى العاملين الصحيين معرفة شاملة بسياسة الالتحاق بالركب؟", "required": true},
          {"key": "catch_up_training", "type": "yesno", "label_ar": "هل تلقى العاملين الصحيين التدريب الكافي لتنفيذ سياسة الالتحاق بالركب بفعالية؟", "required": true},
          {"key": "catch_up_2to5_registration", "type": "yesno", "label_ar": "هل يقوم المطعم بالتطعيم للأطفال من 2 إلى 5 سنوات وتسجيل بياناتهم كجزء من استراتيجية الالتحاق بالركب؟", "required": true},
          {"key": "team_target_knowledge", "type": "yesno", "label_ar": "هل لدى الفريق معرفة بالمستهدف الخاص بالنشاط الايصالي التكاملي للمنطقة (أطفال دون العام، من عام إلى عامين، من عامين إلى خمس أعوام)؟", "required": true}
        ]
      },
      {
        "id": "defaulter_tracking",
        "title_ar": "تتبع المتخلفين",
        "order": 14,
        "fields": [
          {"key": "has_defaulter_mechanism", "type": "yesno", "label_ar": "هل يوجد آلية لتتبع المتخلفين؟", "required": true},
          {"key": "defaulter_mechanism_type", "type": "textarea", "label_ar": "ما هي آلية تتبع المتخلفين المتخذة؟"},
          {"key": "has_previous_vaccination_records", "type": "yesno", "label_ar": "هل يوجد مع الفريق سجل التطعيم المستخدم في الجولات السابقة لمتابعة المتخلفين؟", "required": true}
        ]
      },
      {
        "id": "aefi",
        "title_ar": "الآثار الجانبية",
        "order": 15,
        "fields": [
          {"key": "aefi_knowledge", "type": "yesno", "label_ar": "هل لدى العامل الصحي معرفة حول الآثار الجانبية المعتادة (AEFIs) مثل الحمى أو الألم بعد الحقن؟", "required": true},
          {"key": "aefi_mothers_info", "type": "yesno", "label_ar": "هل يقدم المطعم معلومات للأمهات حول الآثار الجانبية المعتادة (AEFIs)؟", "required": true}
        ]
      }
    ]
  }'::jsonb,
  true,
  true,
  true,
 5
);

-- ============================================================
-- FORM 2: استمارة الجاهزية للنشاط الايصالي
-- Readiness Form for Integrated SIA
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة الجاهزية للنشاط الايصالي التكاملي',
  'Integrated SIA Readiness Form',
  'استمارة تقييم جاهزية المحافظة لتنفيذ النشاط الايصالي التكاملي',
  'Form for assessing governorate readiness to implement integrated supplementary immunization activity',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
        ]
      },
      {
        "id": "readiness_checklist",
        "title_ar": "قائمة تقييم الجاهزية",
        "order": 2,
        "fields": [
          {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية المالية؟", "required": true},
          {"key": "routine_vaccines_available", "type": "yesno", "label_ar": "توفر اللقاحات الروتينية", "required": true},
          {"key": "covid_vaccine_available", "type": "yesno", "label_ar": "توفر لقاح كوفيد", "required": true},
          {"key": "medicines_available", "type": "yesno", "label_ar": "توفر الأدوية", "required": true},
          {"key": "reproductive_supplies_available", "type": "yesno", "label_ar": "توفر مستلزمات الصحة الإنجابية", "required": true},
          {"key": "staff_available", "type": "yesno", "label_ar": "توفر الكادر الصحي", "required": true},
          {"key": "preparatory_meeting_held", "type": "yesno", "label_ar": "هل تم الاجتماع التحضيري للحملة؟", "required": true},
          {"key": "meeting_date", "type": "date", "label_ar": "تاريخ الاجتماع التحضيري"},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي"}
        ]
      },
      {
        "id": "launch_status",
        "title_ar": "حالة التدشين",
        "order": 3,
        "fields": [
          {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة في حالة جاهزية للتدشين؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true},
          {"key": "postponement_reasons", "type": "textarea", "label_ar": "اذكر أسباب التأجيل"},
          {"key": "postponed_launch_date", "type": "date", "label_ar": "تاريخ التدشين المؤجل"}
        ]
      },
      {
        "id": "notes",
        "title_ar": "ملاحظات ومتابعة",
        "order": 4,
        "fields": [
          {"key": "notes", "type": "textarea", "label_ar": "ملاحظات"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true,
  true,
  false,
  0
);

COMMIT;
-- ============================================================
-- EPI Supervisor Platform — Polio Campaign Forms
-- حملة شلل الأطفال
-- Version: 2.0.0
-- ============================================================

BEGIN;

-- Clean duplicates on re-run
DELETE FROM forms WHERE title_ar IN (
  'استمارة جاهزية حملة شلل الأطفال',
  'استمارة الاشراف لحملة شلل الأطفال',
  'استمارة المسح العشوائي لحملة شلل الأطفال'
) AND deleted_at IS NULL;

-- ============================================================
-- FORM 1: استمارة جاهزية حملة الشلل
-- Polio Campaign Readiness Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة جاهزية حملة شلل الأطفال',
  'Polio Campaign Readiness Form',
  'استمارة تقييم جاهزية المحافظة لتنفيذ حملة شلل الأطفال',
  'Form for assessing governorate readiness for polio campaign implementation',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف ميداني", "رئيس فريق"], "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
        ]
      },
      {
        "id": "budget_supplies",
        "title_ar": "الميزانية والمستلزمات",
        "order": 2,
        "fields": [
          {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية المالية؟", "required": true},
          {"key": "vaccines_distributed", "type": "yesno", "label_ar": "هل تم إمداد اللقاحات للمديريات؟", "required": true},
          {"key": "iiv_materials_distributed", "type": "yesno", "label_ar": "هل تم إمداد المواد التثقيفية للمديريات؟", "required": true}
        ]
      },
      {
        "id": "health_education",
        "title_ar": "التثقيف الصحي",
        "order": 3,
        "fields": [
          {"key": "he_started", "type": "yesno", "label_ar": "هل تم البدء بأنشطة التثقيف الصحي؟", "required": true},
          {"key": "he_start_date", "type": "date", "label_ar": "تاريخ بدء أنشطة التثقيف الصحي"}
        ]
      },
      {
        "id": "coordination",
        "title_ar": "الاجتماع التحضيري",
        "order": 4,
        "fields": [
          {"key": "preparatory_meeting_held", "type": "yesno", "label_ar": "هل تم الاجتماع التحضيري للحملة؟", "required": true},
          {"key": "meeting_date", "type": "date", "label_ar": "تاريخ الاجتماع التحضيري"}
        ]
      },
      {
        "id": "training",
        "title_ar": "التدريب",
        "order": 5,
        "fields": [
          {"key": "training_started", "type": "yesno", "label_ar": "هل تم البدء بعملية التدريب؟", "required": true},
          {"key": "training_quality", "type": "select", "label_ar": "جودة التدريب", "options": ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"], "required": true},
          {"key": "training_date", "type": "date", "label_ar": "تاريخ التدريب"},
          {"key": "training_pros_cons", "type": "textarea", "label_ar": "الإيجابيات والسلبيات لعملية التدريب"}
        ]
      },
      {
        "id": "launch_status",
        "title_ar": "حالة التدشين",
        "order": 6,
        "fields": [
          {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة في حالة جاهزية للتدشين؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true},
          {"key": "postponement_reasons", "type": "textarea", "label_ar": "اذكر أسباب التأجيل"},
          {"key": "postponed_launch_date", "type": "date", "label_ar": "تاريخ التدشين المؤجل"}
        ]
      },
      {
        "id": "signature",
        "title_ar": "التوقيع",
        "order": 7,
        "fields": [
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ============================================================
-- FORM 2: استمارة الاشراف لحملة الشلل
-- Polio Campaign Supervision Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة الاشراف لحملة شلل الأطفال',
  'Polio Campaign Supervision Form',
  'استمارة شاملة للإشراف الميداني على فرق حملة شلل الأطفال',
  'Comprehensive field supervision form for polio campaign teams',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_level", "type": "select", "label_ar": "المستوى", "options": ["مستوى أول", "مستوى ثاني", "مستوى ثالث", "مستوى رابع"], "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "health_facility", "type": "text", "label_ar": "المرفق الصحي التابع للفريق", "required": true},
          {"key": "village_name", "type": "text", "label_ar": "اسم القرية التي يعمل بها الفريق", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true},
          {"key": "team_type", "type": "select", "label_ar": "نوع الفريق", "options": ["فريق ثابت", "فريق متحرك", "فريق مشترك"], "required": true},
          {"key": "team_members_count", "type": "number", "label_ar": "عدد أعضاء الفريق", "required": true},
          {"key": "trained_members_count", "type": "number", "label_ar": "عدد المدربين منهم", "required": true},
          {"key": "team_members_names", "type": "textarea", "label_ar": "أسماء أعضاء الفريق", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true}
        ]
      },
      {
        "id": "team_presence",
        "title_ar": "تواجد الفريق",
        "order": 2,
        "fields": [
          {"key": "vaccinators_count", "type": "number", "label_ar": "عدد المطعمين وقت الزيارة", "required": true},
          {"key": "both_members_present", "type": "yesno", "label_ar": "هل عنصري الفريق متواجدين وقت الزيارة؟", "required": true},
          {"key": "has_female_member", "type": "yesno", "label_ar": "هل توجد امرأة عضو في الفريق؟", "required": true},
          {"key": "local_member", "type": "yesno", "label_ar": "هل يوجد عضو في الفريق من نفس المنطقة؟", "required": true},
          {"key": "has_id_cards", "type": "yesno", "label_ar": "هل لدى الفريق كروت تعريف؟", "required": true}
        ]
      },
      {
        "id": "work_plan",
        "title_ar": "خطة العمل والتنقل",
        "order": 3,
        "fields": [
          {"key": "has_daily_route_map", "type": "yesno", "label_ar": "هل توجد لدى الفريق خطة لخط سير للعمل اليوم موضحة برسم كروكي؟", "required": true},
          {"key": "can_locate_on_map", "type": "yesno", "label_ar": "هل يستطيع الفريق تحديد مكانه على الخارطة؟", "required": true},
          {"key": "mobile_team_h2h", "type": "yesno", "label_ar": "هل يقوم الفريق المتحرك بالتنقل من منزل إلى منزل بحسب خطة السير؟", "required": true},
          {"key": "personal_contact_rules", "type": "yesno", "label_ar": "هل يطبق الفريق قواعد الاتصال الشخصي؟", "required": true}
        ]
      },
      {
        "id": "vaccination_practice",
        "title_ar": "ممارسة التطعيم",
        "order": 4,
        "fields": [
          {"key": "asks_all_under5", "type": "yesno", "label_ar": "هل يسأل الفريق على جميع الأطفال دون الخامسة والمتغيبين؟", "required": true},
          {"key": "correct_drops_45deg", "type": "yesno", "label_ar": "هل يقوم الفريق بإعطاء قطرتين من اللقاح وبزاوية 45 درجة بطريقة صحيحة؟", "required": true},
          {"key": "confirms_swallowing", "type": "yesno", "label_ar": "هل يتم التأكد من قبل الفريق من بلع الطفل للقاح؟", "required": true},
          {"key": "correct_daily_register", "type": "yesno", "label_ar": "هل يتم تسجيل بيانات الأطفال المطعمين والمتغيبين والرافضين في دفتر الإحصاء اليومي بالشكل الصحيح؟", "required": true},
          {"key": "follows_defaulters", "type": "yesno", "label_ar": "هل يتم متابعة المتغيبين والعودة لتطعيمهم؟", "required": true},
          {"key": "marks_fingers_correctly", "type": "yesno", "label_ar": "هل يقوم الفريق بتعليم أصابع الأطفال المطعمين بطريقة صحيحة؟", "required": true},
          {"key": "marks_houses_correctly", "type": "yesno", "label_ar": "هل يقوم الفريق بوضع العلامات على المنازل بطريقة صحيحة؟", "required": true}
        ]
      },
      {
        "id": "supplies",
        "title_ar": "المستلزمات واللقاحات",
        "order": 5,
        "fields": [
          {"key": "has_sufficient_supplies", "type": "yesno", "label_ar": "هل يوجد مع الفريق التموين الكافي من المستلزمات (دفتر الإحصاء الاسمي/طباشير/قلم علامة)؟", "required": true},
          {"key": "sufficient_vials", "type": "yesno", "label_ar": "هل يوجد مع الفريق كمية كافية من لقاح الشلل والقطارات الخاصة به؟", "required": true},
          {"key": "proper_cold_chain", "type": "yesno", "label_ar": "هل قنينات لقاح الشلل محفوظة في كيس حراري داخل الحافظة وبها قوالب باردة؟", "required": true},
          {"key": "understands_vvm", "type": "yesno", "label_ar": "هل يفهم الفريق مؤشر مراقبة اللقاح (VVM)؟", "required": true},
          {"key": "vvm_status_correct", "type": "yesno", "label_ar": "هل مؤشر مراقبة اللقاح في القنينة في الوضع السليم؟", "required": true}
        ]
      },
      {
        "id": "supervision_level",
        "title_ar": "الإشراف الإلكتروني",
        "order": 6,
        "fields": [
          {"key": "uses_electronic_app", "type": "yesno", "label_ar": "هل يستخدم مشرف الفرق التطبيق الالكتروني للإشراف على الفرق؟", "required": true},
          {"key": "daily_team_visit", "type": "yesno", "label_ar": "هل يقوم مشرف الفريق بزيارة الفريق مرة واحدة على الأقل في اليوم؟", "required": true},
          {"key": "guides_and_notes", "type": "yesno", "label_ar": "هل مشرف الفريق يرشد ويوجه الفريق ويدون الملاحظات والتعليمات في استمارة الزيارات؟", "required": true}
        ]
      },
      {
        "id": "surveillance",
        "title_ar": "الترصد الوبائي",
        "order": 7,
        "fields": [
          {"key": "asks_about_aps", "type": "yesno", "label_ar": "هل يسأل العامل الصحي عن وجود حالات شلل مشتبهة (APS)؟", "required": true},
          {"key": "has_ppe", "type": "yesno", "label_ar": "هل تتوفر مع الفريق أدوات الحماية (كمامات - معقم يد)؟", "required": true}
        ]
      },
      {
        "id": "reverse_supply",
        "title_ar": "الإمداد العكسي",
        "order": 8,
        "fields": [
          {"key": "daily_reverse_tracking", "type": "yesno", "label_ar": "هل يتم تسجيل بيانات الإمداد العكسي من قبل مشرف الفريق بشكل يومي ومكتمل؟", "required": true}
        ]
      },
      {
        "id": "waste_management",
        "title_ar": "إدارة النفايات الطبية",
        "order": 9,
        "fields": [
          {"key": "has_sharps_and_waste_bags", "type": "yesno", "label_ar": "هل توجد لدي الفريق كيس التخلص (الأحمر والوردي - قابلان لإعادة الإغلاق والفتح) قيد الاستخدام؟", "required": true},
          {"key": "collects_sharps_immediately", "type": "yesno", "label_ar": "هل يقوم الفريق بجمع الفيالات المستخدمة مع قطاراتها أو الغير صالحة أول بأول وبشكل مباشر للكيس الأحمر؟", "required": true},
          {"key": "collects_masks_immediately", "type": "yesno", "label_ar": "هل يقوم الفريق بجمع الكمامات المستخدمة أول بأول وبشكل مباشر للكيس الوردي؟", "required": true},
          {"key": "correct_bag_labeling", "type": "yesno", "label_ar": "هل تسجل البيانات المطلوبة على الكيس الأحمر والوردي بشكل واضح وصحيح (اليوم/التاريخ/رقم الفريق...الخ)؟", "required": true},
          {"key": "vial_count_matches", "type": "yesno", "label_ar": "هل عدد الفيالات داخل الكيس الأحمر والمتبقي داخل الحافظة اليومية يساوي إجمالي عدد الفيالات المستلمة؟", "required": true},
          {"key": "daily_bag_handover", "type": "yesno", "label_ar": "هل يقوم الفريق نهاية كل يوم عمل بتسليم الكيس الأحمر والوردي لمشرف الفريق؟", "required": true}
        ]
      },
      {
        "id": "challenges",
        "title_ar": "التحديات والتوصيات",
        "order": 10,
        "fields": [
          {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
          {"key": "actions_taken", "type": "textarea", "label_ar": "الإجراءات المتخذة", "required": true},
          {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
          {"key": "supervision_photo", "type": "photo", "label_ar": "صورة توثيقية للنزول الاشرافي"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      },
      {
        "id": "vitamin_a",
        "title_ar": "فيتامين أ",
        "order": 11,
        "fields": [
          {"key": "supervisor_title_va", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف ميداني", "رئيس فريق"]},
          {"key": "has_vitamin_a", "type": "yesno", "label_ar": "هل يتوفر فيتامين أ (100 ألف وحدة و 200 ألف وحدة) لدى الفريق؟", "required": true},
          {"key": "correct_vitamin_a_admin", "type": "yesno", "label_ar": "هل يتم إعطاء فيتامين أ للأطفال بشكل صحيح وبحسب الفئات العمرية؟", "required": true},
          {"key": "has_scissors_container", "type": "yesno", "label_ar": "هل يتوفر لدى الفريق مقص وعلبة بلاستيكية لحفظ الفيتامين؟", "required": true}
        ]
      }
    ]
  }'::jsonb,
  true, true, true, 5
);

-- ============================================================
-- FORM 3: استمارة المسح العشوائي لحملة الشلل
-- Polio Campaign Random Survey Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة المسح العشوائي لحملة شلل الأطفال',
  'Polio Campaign Random Survey Form',
  'استمارة لإجراء مسح عشوائي لتقييم تغطية التطعيم أثناء حملة شلل الأطفال',
  'Form for conducting random survey to assess vaccination coverage during polio campaign',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_level", "type": "select", "label_ar": "المستوى", "options": ["مستوى أول", "مستوى ثاني", "مستوى ثالث", "مستوى رابع"], "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "sub_district", "type": "text", "label_ar": "العزلة", "required": true},
          {"key": "neighborhood", "type": "text", "label_ar": "الحارة", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true}
        ]
      },
      {
        "id": "household_info",
        "title_ar": "بيانات المنزل",
        "order": 2,
        "fields": [
          {"key": "house_number", "type": "text", "label_ar": "رقم المنزل", "required": true},
          {"key": "house_owner_name", "type": "text", "label_ar": "اسم صاحب المنزل", "required": true}
        ]
      },
      {
        "id": "under5_summary",
        "title_ar": "ملخص أطفال دون الخامسة",
        "order": 3,
        "fields": [
          {"key": "total_under5", "type": "number", "label_ar": "إجمالي عدد الأطفال دون الخامسة", "required": true},
          {"key": "vaccinated_under5", "type": "number", "label_ar": "عدد الأطفال المطعمين دون الخامسة", "required": true},
          {"key": "unvaccinated_under5", "type": "number", "label_ar": "عدد الأطفال غير المطعمين دون الخامسة", "required": true}
        ]
      },
      {
        "id": "age_0_11m",
        "title_ar": "الفئة العمرية 0-11 شهر",
        "order": 4,
        "fields": [
          {"key": "total_0_11m", "type": "number", "label_ar": "إجمالي عدد الأطفال من 0-11 شهر", "required": true},
          {"key": "vaccinated_0_11m", "type": "number", "label_ar": "عدد المطعمين منهم من 0-11 شهر", "required": true},
          {"key": "unvaccinated_0_11m", "type": "number", "label_ar": "عدد غير المطعمين من 0-11 شهر", "required": true}
        ]
      },
      {
        "id": "age_12_59m",
        "title_ar": "الفئة العمرية 12-59 شهر",
        "order": 5,
        "fields": [
          {"key": "total_12_59m", "type": "number", "label_ar": "إجمالي عدد الأطفال 12-59 شهر", "required": true},
          {"key": "vaccinated_12_59m", "type": "number", "label_ar": "عدد المطعمين منهم 12-59 شهر", "required": true},
          {"key": "unvaccinated_12_59m", "type": "number", "label_ar": "عدد غير المطعمين 12-59 شهر", "required": true}
        ]
      },
      {
        "id": "refusal_reasons",
        "title_ar": "أسباب عدم التطعيم",
        "order": 6,
        "fields": [
          {"key": "non_vaccination_reasons", "type": "textarea", "label_ar": "أسباب عدم التطعيم"},
          {"key": "refusal_reasons", "type": "textarea", "label_ar": "أسباب الرفض اذكرها"}
        ]
      },
      {
        "id": "house_marking",
        "title_ar": "علامة المنزل",
        "order": 7,
        "fields": [
          {"key": "house_marking", "type": "text", "label_ar": "علامة المنزل"}
        ]
      },
      {
        "id": "supervisor_vaccination",
        "title_ar": "تطعيم بواسطة المشرف",
        "order": 8,
        "fields": [
          {"key": "vaccinated_by_supervisor", "type": "number", "label_ar": "عدد الأطفال المطعمين بواسطة المشرف الزائر (مشرفي الفرق)"}
        ]
      },
      {
        "id": "final",
        "title_ar": "التوقيع",
        "order": 9,
        "fields": [
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ============================================================
-- END OF POLIO CAMPAIGN FORMS
-- ============================================================

COMMIT;
-- ============================================================
-- Yemen Health Facilities Data
-- Generated from المرافق_الصحية.xlsx
-- ============================================================
BEGIN;

-- Clean existing data (in FK-safe order: children first)
-- NOTE: We use ON CONFLICT DO NOTHING for inserts, so cleanup is only needed
-- for a truly fresh start. With the new code scheme, duplicates are avoided.

-- Health facilities table
CREATE TABLE IF NOT EXISTS health_facilities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  district_id UUID NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  facility_type TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_facilities_district ON health_facilities(district_id) WHERE deleted_at IS NULL;

DO $$
BEGIN
  -- Enable RLS only if not already enabled
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables WHERE tablename = 'health_facilities' AND rowsecurity = true
  ) THEN
    ALTER TABLE health_facilities ENABLE ROW LEVEL SECURITY;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'health_facilities' AND policyname = 'facilities_select_all'
  ) THEN
    CREATE POLICY "facilities_select_all" ON health_facilities FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'health_facilities' AND policyname = 'facilities_modify_admin'
  ) THEN
    CREATE POLICY "facilities_modify_admin" ON health_facilities FOR ALL USING (public.user_role() = 'admin');
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- Safe cleanup in FK order (only if re-running migration)
DELETE FROM health_facilities WHERE code LIKE '%-%-%';
DELETE FROM districts WHERE code LIKE '%-%';
DELETE FROM governorates WHERE code IN ('ABYAN','ADEN','ALBAYD','ALDHAL','ALHUDA','ALMAHA','ALMUKA','LAHJ','MARIB','SAYUN','SHABWA','SOCOTR','TAIZZ');

INSERT INTO governorates (name_ar, name_en, code) VALUES ('أبين', 'Abyan', 'ABYAN') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('عدن', 'Aden', 'ADEN') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('البيضاء', 'Al Bayda', 'ALBAYD') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('الضالع', 'Al Dhale''e', 'ALDHAL') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('الحديدة', 'Al Hudaydah', 'ALHUDA') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('المهرة', 'Al Maharah', 'ALMAHA') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('المكلا', 'Al Mukalla', 'ALMUKA') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('لحج', 'Lahj', 'LAHJ') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('مأرب', 'Marib', 'MARIB') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('سيئون', 'Sayun', 'SAYUN') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('شبوة', 'Shabwah', 'SHABWA') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('سقطرى', 'Socotra', 'SOCOTR') ON CONFLICT (code) DO NOTHING;
INSERT INTO governorates (name_ar, name_en, code) VALUES ('تعز', 'Taizz', 'TAIZZ') ON CONFLICT (code) DO NOTHING;

-- Districts
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'احوار', 'Ahwar', 'ABYAN-AHWAR' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المحفد', 'Al Mahfad', 'ABYAN-ALMAHF' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الوضيع', 'Al Wade''a', 'ABYAN-ALWADE' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'جيشان', 'Jayshan', 'ABYAN-JAYSHA' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'خنفر', 'Khanfir', 'ABYAN-KHANFI' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'لودر', 'Lawdar', 'ABYAN-LAWDAR' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'موديه', 'Mudiyah', 'ABYAN-MUDIYA' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'رصد', 'Rasad', 'ABYAN-RASAD' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'سرار', 'Sarar', 'ABYAN-SARAR' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'سباح', 'Sibah', 'ABYAN-SIBAH' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'زنجبار', 'Zingibar', 'ABYAN-ZINGIB' FROM governorates WHERE code = 'ABYAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'البريقه', 'Al Buraiqeh', 'ADEN-ALBURA' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المنصورة', 'Al Mansura', 'ADEN-ALMANS' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المعلا', 'Al Mualla', 'ADEN-ALMUAL' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الشيخ عثمان', 'Ash Shaikh Outhman', 'ADEN-ASHSHA' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'التواهي', 'Attawahi', 'ADEN-ATTAWA' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'كريتر', 'Craiter', 'ADEN-CRAITE' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'دار سعد', 'Dar Sad', 'ADEN-DARSAD' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'خور مكسر', 'Khur Maksar', 'ADEN-KHURMA' FROM governorates WHERE code = 'ADEN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'نعمان', 'Na''man', 'ALBAYD-NA''MAN' FROM governorates WHERE code = 'ALBAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الضالع', 'Ad Dhale''e', 'ALDHAL-ADDHAL' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الازارق', 'Al Azariq', 'ALDHAL-ALAZAR' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الحصين', 'Al Hussein', 'ALDHAL-ALHUSS' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الشعيب', 'Ash Shu''ayb', 'ALDHAL-ASHSHU' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'جحاف', 'Jahaf', 'ALDHAL-JAHAF' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'قعطبة', 'Qa''atabah', 'ALDHAL-QA''ATA' FROM governorates WHERE code = 'ALDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الخوخه', 'Al Khawkhah', 'ALHUDA-ALKHAW' FROM governorates WHERE code = 'ALHUDA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'التحيتا', 'At Tuhayat', 'ALHUDA-ATTUHA' FROM governorates WHERE code = 'ALHUDA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حيس', 'Hays', 'ALHUDA-HAYS' FROM governorates WHERE code = 'ALHUDA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الغيظه', 'Al Ghaydah', 'ALMAHA-ALGHAY' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المسيلة', 'Al Masilah', 'ALMAHA-ALMASI' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حات', 'Hat', 'ALMAHA-HAT' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حوف', 'Hawf', 'ALMAHA-HAWF' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حصوين', 'Huswain', 'ALMAHA-HUSWAI' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'منعر', 'Man''ar', 'ALMAHA-MAN''AR' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'قشن', 'Qishn', 'ALMAHA-QISHN' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'سيحوت', 'Sayhut', 'ALMAHA-SAYHUT' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'شحن', 'Shahan', 'ALMAHA-SHAHAN' FROM governorates WHERE code = 'ALMAHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الديس', 'Ad Dis', 'ALMUKA-ADDIS' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الضليعه', 'Adh Dhlia''ah', 'ALMUKA-ADHDHL' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المكلا', 'Al Mukalla', 'ALMUKA-ALMUKA' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مدينة المكلا', 'Al Mukalla City', 'ALMUKA-MUKLAC' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الريده وقصيعر', 'Ar Raydah Wa Qusayar', 'ALMUKA-ARRAYD' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الشحر', 'Ash Shihr', 'ALMUKA-ASHSHI' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'بروم ميفع', 'Brom Mayfa', 'ALMUKA-BROMMA' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'دوعن', 'Daw''an', 'ALMUKA-DAW''AN' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'غيل باوزير', 'Ghayl Ba Wazir', 'ALMUKA-GHAYLB' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'غيل بن يمين', 'Ghayl Bin Yamin', 'ALMUKA-GHAYLY' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حجر', 'Hajr', 'ALMUKA-HAJR' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'يبعث', 'Yabuth', 'ALMUKA-YABUTH' FROM governorates WHERE code = 'ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الحوطة', 'Al  Hawtah', 'LAHJ-ALHAWT' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الحد', 'Al Had', 'LAHJ-ALHAD' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المضاربة و العاره', 'Al Madaribah Wa Al Arah', 'LAHJ-ALMADA' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المفلحي', 'Al Maflahy', 'LAHJ-ALMAFL' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المقاطرة', 'Al Maqatirah', 'LAHJ-ALMAQA' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الملاح', 'Al Milah', 'LAHJ-ALMILA' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المسيمير', 'Al Musaymir', 'LAHJ-ALMUSA' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'القبيطه', 'Al Qabbaytah', 'LAHJ-ALQABB' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حبيل جبر', 'Habil Jabr', 'LAHJ-HABILJ' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حالمين', 'Halimayn', 'LAHJ-HALIMA' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'ردفان', 'Radfan', 'LAHJ-RADFAN' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'تبن', 'Tuban', 'LAHJ-TUBAN' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'طور الباحة', 'Tur Al Bahah', 'LAHJ-TURALB' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'يافع', 'Yafa''a', 'LAHJ-YAFA''A' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'يهر', 'Yahr', 'LAHJ-YAHR' FROM governorates WHERE code = 'LAHJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حريب', 'Harib', 'MARIB-HARIB' FROM governorates WHERE code = 'MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مأرب', 'Marib', 'MARIB-MARIB' FROM governorates WHERE code = 'MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مدينة مأرب', 'Marib City', 'MARIB-MARIBC' FROM governorates WHERE code = 'MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مدغل', 'Medghal', 'MARIB-MEDGHA' FROM governorates WHERE code = 'MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'رغوان', 'Raghwan', 'MARIB-RAGHWA' FROM governorates WHERE code = 'MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'العبر', 'Al Abr', 'SAYUN-ALABR' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'القف', 'Al Qaf', 'SAYUN-ALQAF' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'القطن', 'Al Qatn', 'SAYUN-ALQATN' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'عمد', 'Amd', 'SAYUN-AMD' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'السوم', 'As Sawm', 'SAYUN-ASSAWM' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حجر الصيعر', 'Hagr As Sai''ar', 'SAYUN-HAGRAS' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حريضه', 'Huraidhah', 'SAYUN-HURAID' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'رخيه', 'Rakhyah', 'SAYUN-RAKHYA' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'رماه', 'Rumah', 'SAYUN-RUMAH' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'ساه', 'Sah', 'SAYUN-SAH' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'سيئون', 'Sayun', 'SAYUN-SAYUN' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'شبام', 'Shibam', 'SAYUN-SHIBAM' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'تريم', 'Tarim', 'SAYUN-TARIM' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'ثمود', 'Thamud', 'SAYUN-THAMUD' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'وادي العين وحوره', 'Wadi Al Ayn', 'SAYUN-WADIAL' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'زموخ ومنوخ', 'Zamakh wa Manwakh', 'SAYUN-ZAMAKH' FROM governorates WHERE code = 'SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'عين', 'Ain', 'SHABWA-AIN' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الطلح', 'Al Talh', 'SHABWA-ALTALH' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الروضه', 'Ar Rawdah', 'SHABWA-ARRAWD' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'عرماء', 'Arma', 'SHABWA-ARMA' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الصعيد', 'As Said', 'SHABWA-ASSAID' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'عتق', 'Ataq', 'SHABWA-ATAQ' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'بيحان', 'Bayhan', 'SHABWA-BAYHAN' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'دهر', 'Dhar', 'SHABWA-DHAR' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حبان', 'Habban', 'SHABWA-HABBAN' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حطيب', 'Hatib', 'SHABWA-HATIB' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'جردان', 'Jardan', 'SHABWA-JARDAN' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مرخه العليا', 'Merkhah Al Ulya', 'SHABWA-MERKHA' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مرخه السفلى', 'Merkhah As Sufla', 'SHABWA-MERKHS' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'نصاب', 'Nisab', 'SHABWA-NISAB' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'رضوم', 'Rudum', 'SHABWA-RUDUM' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'عسيلان', 'Usaylan', 'SHABWA-USAYLA' FROM governorates WHERE code = 'SHABWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'حديبو', 'Hidaybu', 'SOCOTR-HIDAYB' FROM governorates WHERE code = 'SOCOTR' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'قلنسيه وعبدالكوري', 'Qulensya Wa Abd Al Kuri', 'SOCOTR-QULENS' FROM governorates WHERE code = 'SOCOTR' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المخاء', 'Al  Mukha', 'TAIZZ-ALMUKH' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المعافر', 'Al Ma''afer', 'TAIZZ-ALMA''A' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المواسط', 'Al Mawasit', 'TAIZZ-ALMAWA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المسراخ', 'Al Misrakh', 'TAIZZ-ALMISR' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'المظفر', 'Al Mudhaffar', 'TAIZZ-ALMUDH' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'القاهرة', 'Al Qahirah', 'TAIZZ-ALQAHI' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الوازعية', 'Al Wazi''iyah', 'TAIZZ-ALWAZI' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الصلو', 'As Silw', 'TAIZZ-ASSILW' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'الشمايتين', 'Ash Shamayatayn', 'TAIZZ-ASHSHA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'ذباب', 'Dhubab', 'TAIZZ-DHUBAB' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'جبل حبشي', 'Jabal Habashy', 'TAIZZ-JABALH' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مقبنة', 'Maqbanah', 'TAIZZ-MAQBAN' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'مشرعة وحدنان', 'Mashra''a Wa Hadnan', 'TAIZZ-MASHRA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'موزع', 'Mawza', 'TAIZZ-MAWZA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'صبر الموادم', 'Sabir Al Mawadim', 'TAIZZ-SABIRA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'صالة', 'Salh', 'TAIZZ-SALH' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;
INSERT INTO districts (governorate_id, name_ar, name_en, code) SELECT id, 'سامع', 'Sama', 'TAIZZ-SAMA' FROM governorates WHERE code = 'TAIZZ' ON CONFLICT (code) DO NOTHING;

-- Health Facilities
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى احور الريفي', 'Ahwr Rural  H', 'ABYAN-AHWAR-AHWRRURALH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-AHWAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المحصامة', 'Almohsamh HU', 'ABYAN-AHWAR-ALMOHSAMHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-AHWAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المساني', 'Almsani HU', 'ABYAN-AHWAR-ALMSANIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-AHWAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'ألوحدة الصحية الرصراص', 'Alrsras HU', 'ABYAN-AHWAR-ALRSRASHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-AHWAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية باساحم', 'Basaham HU', 'ABYAN-AHWAR-BASAHAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-AHWAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العين', 'Alain HU', 'ABYAN-ALMAHF-ALAINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه العرق', 'Alerek HU', 'ABYAN-ALMAHF-ALEREKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجدبة', 'Aljdph HU', 'ABYAN-ALMAHF-ALJDPHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكفاه', 'Alkafah HU', 'ABYAN-ALMAHF-ALKAFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعجلة', 'Almajalah HU', 'ABYAN-ALMAHF-ALMAJALAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الرحبه', 'Alrahabh HU', 'ABYAN-ALMAHF-ALRAHABHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشهيد صلاح ناصرمحمد', 'Alshahid Slah Nasser Mohammed H', 'ABYAN-ALMAHF-ALSHAHIDSL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لباخة', 'Lbakha HU', 'ABYAN-ALMAHF-LBAKHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سناج', 'Snaj HU', 'ABYAN-ALMAHF-SNAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صندوق الشرقي', 'Sonduq Alshrqi HU', 'ABYAN-ALMAHF-SONDUQALSH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALMAHF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجدار', 'Al Jdar HU', 'ABYAN-ALWADE-ALJDARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفرع', 'Alfra HU', 'ABYAN-ALWADE-ALFRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحردوب', 'Alhardwb HU', 'ABYAN-ALWADE-ALHARDWBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكورة', 'Alkorah  HU', 'ABYAN-ALWADE-ALKORAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المقطن', 'Almqtn HU', 'ABYAN-ALWADE-ALMQTNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الوضيع', 'Alwadhee H', 'ABYAN-ALWADE-ALWADHEEH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امنقع', 'Amnqa HU', 'ABYAN-ALWADE-AMNQAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة االصحية المركد', 'Amrkd HU', 'ABYAN-ALWADE-AMRKDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عزان', 'Azan HC', 'ABYAN-ALWADE-AZANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جريزفان', 'Jrizfan HU', 'ABYAN-ALWADE-JRIZFANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لبو', 'Labw HU', 'ABYAN-ALWADE-LABWHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ALWADE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امسند', 'Amsand HU', 'ABYAN-JAYSHA-AMSANDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ظراء مرحوم', 'Dhara Mrhum HU', 'ABYAN-JAYSHA-DHARAMRHUM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حيب', 'Habib HU', 'ABYAN-JAYSHA-HABIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جابرة', 'Japrh HU', 'ABYAN-JAYSHA-JAPRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جيشان', 'Jishan HC', 'ABYAN-JAYSHA-JISHANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جيشان', 'Jishan HU', 'ABYAN-JAYSHA-JISHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رحاب', 'Rehab HU', 'ABYAN-JAYSHA-REHABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-JAYSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي المسيمير', 'ALMUSAIMEER HC', 'ABYAN-KHANFI-ALMUSAIMEE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عبر عثمان', 'Abr Othman HU', 'ABYAN-KHANFI-ABROTHMANH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه المخزن', 'Al Makzan Maternity & Childhood Center', 'ABYAN-KHANFI-ALMAKZANMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه الكود', 'Al kawd Maternity & Childhood Center', 'ABYAN-KHANFI-ALKAWDMATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدرجاج', 'Aldrjaj HU', 'ABYAN-KHANFI-ALDRJAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحرور', 'Alharour HU', 'ABYAN-KHANFI-ALHAROURHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحصحوص', 'AlhasHos HU', 'ABYAN-KHANFI-ALHASHOSHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحصن', 'Alhusn HC', 'ABYAN-KHANFI-ALHUSNHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجول الشعبية', 'Aljwl Alshapiah HU', 'ABYAN-KHANFI-ALJWLALSHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الخبر للصحه الانجابيه', 'Alkhabr MCH HC', 'ABYAN-KHANFI-ALKHABRMCH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخاملة', 'Alkhamela HU', 'ABYAN-KHANFI-ALKHAMELAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الكود', 'Alkood HC', 'ABYAN-KHANFI-ALKOODHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الميوح', 'Almiuh HU', 'ABYAN-KHANFI-ALMIUHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القرنعة', 'Alqurnah HU', 'ABYAN-KHANFI-ALQURNAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرميلة', 'Alromilah HU', 'ABYAN-KHANFI-ALROMILAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرواء', 'Alrwa''a HU', 'ABYAN-KHANFI-ALRWA''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الطرية', 'Altrih HU', 'ABYAN-KHANFI-ALTRIHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امسواد يرامس', 'Amswad Yramis HU', 'ABYAN-KHANFI-AMSWADYRAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عرشان', 'Arashan HU', 'ABYAN-KHANFI-ARASHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي باتيس', 'Batis HC', 'ABYAN-KHANFI-BATISHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بئر الشيخ', 'Bir Alshaikh HU', 'ABYAN-KHANFI-BIRALSHAIK' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جول يرامس', 'Gool Yrams HU', 'ABYAN-KHANFI-GOOLYRAMSH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه حلمه', 'Hlmh HU', 'ABYAN-KHANFI-HLMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جعار', 'Jaar HC', 'ABYAN-KHANFI-JAARHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة جعار', 'Jaar Maternity & Childhood Center', 'ABYAN-KHANFI-JAARMATERN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عسلان', 'Kadamat Asalan HU', 'ABYAN-KHANFI-KADAMATASA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كبث', 'Kubot HU', 'ABYAN-KHANFI-KUBOTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه ساكن وعيص', 'Sakn Wais HU', 'ABYAN-KHANFI-SAKNWAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي شقرة', 'Shoqra HC', 'ABYAN-KHANFI-SHOQRAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة  شقرة', 'Shoqra Maternity & Childhood Center', 'ABYAN-KHANFI-SHOQRAMATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كدمة السيد قاسم', 'kedma al-seed qassem HU', 'ABYAN-KHANFI-KEDMAAL-SE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-KHANFI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدريب', 'Ad Driab HU', 'ABYAN-LAWDAR-ADDRIABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفجاج', 'Al Fjaj HU', 'ABYAN-LAWDAR-ALFJAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المشرقة', 'Al Mashrekah HU', 'ABYAN-LAWDAR-ALMASHREKA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النجدة', 'Al Najdah HU', 'ABYAN-LAWDAR-ALNAJDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القاع', 'Al Qaa HU', 'ABYAN-LAWDAR-ALQAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العبر', 'Al abr HU', 'ABYAN-LAWDAR-ALABRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العين', 'Alain HU', 'ABYAN-LAWDAR-ALAINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغافرية', 'Alghafriah HU', 'ABYAN-LAWDAR-ALGHAFRIAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغوز', 'Alghwz HU', 'ABYAN-LAWDAR-ALGHWZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحضن', 'Alhdhn HC', 'ABYAN-LAWDAR-ALHDHNHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحميشة', 'Alhmishah HU', 'ABYAN-LAWDAR-ALHMISHAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجوف', 'Aljwf HU', 'ABYAN-LAWDAR-ALJWFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخديرة', 'Alkhdirh HU', 'ABYAN-LAWDAR-ALKHDIRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخيالة', 'Alkhialh HU', 'ABYAN-LAWDAR-ALKHIALHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخسعة', 'Alkhusea HU', 'ABYAN-LAWDAR-ALKHUSEAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المسحال', 'Almisshal HU', 'ABYAN-LAWDAR-ALMISSHALH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشعراء', 'Alshoaraa HU', 'ABYAN-LAWDAR-ALSHOARAAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصعيد', 'Alssaid HU', 'ABYAN-LAWDAR-ALSSAIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي اماجل', 'Amajl HC', 'ABYAN-LAWDAR-AMAJLHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امدخلة', 'Amdkhlh HU', 'ABYAN-LAWDAR-AMDKHLHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية أمشعه', 'Amshah HU', 'ABYAN-LAWDAR-AMSHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي امصرة', 'Amssrah HC', 'ABYAN-LAWDAR-AMSSRAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دمان', 'Dman HU', 'ABYAN-LAWDAR-DMANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية غنة', 'Ghannah HU', 'ABYAN-LAWDAR-GHANNAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هشان', 'Hashan HU', 'ABYAN-LAWDAR-HASHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جحين', 'Jhin HU', 'ABYAN-LAWDAR-JHINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى لودر-محنف', 'Mahnf-Lwdr H', 'ABYAN-LAWDAR-MAHNF-LWDR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مقيفعة', 'Mqifah HU', 'ABYAN-LAWDAR-MQIFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شوحط', 'Shaohad HU', 'ABYAN-LAWDAR-SHAOHADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زاره', 'Zarah  HU', 'ABYAN-LAWDAR-ZARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-LAWDAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المقر', 'Al Makar HU', 'ABYAN-MUDIYA-ALMAKARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البطان', 'Albtan HU', 'ABYAN-MUDIYA-ALBTANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المدارة', 'Almdarh HU', 'ABYAN-MUDIYA-ALMDARHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البقيرة', 'Alpoqirh HU', 'ABYAN-MUDIYA-ALPOQIRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القليته', 'Alqlitah HU', 'ABYAN-MUDIYA-ALQLITAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القوز', 'Alqwz HU', 'ABYAN-MUDIYA-ALQWZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الروضة', 'Alrwdah HU', 'ABYAN-MUDIYA-ALRWDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صرة المشائخ', 'Amssrah Al mashayikh HU', 'ABYAN-MUDIYA-AMSSRAHALM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اورمة', 'Aurmh HU', 'ABYAN-MUDIYA-AURMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجبله - لوزنة', 'Jabalh HU', 'ABYAN-MUDIYA-JABALHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جوعر', 'Jaoar HU', 'ABYAN-MUDIYA-JAOARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي كوكب', 'Kawkab HU', 'ABYAN-MUDIYA-KAWKABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لحمر', 'Lahmar HU', 'ABYAN-MUDIYA-LAHMARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مران', 'Marran HU', 'ABYAN-MUDIYA-MARRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحة الانجابية موديه', 'Mudiyah Maternity & Childhood Center', 'ABYAN-MUDIYA-MUDIYAHMAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-MUDIYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الضبة', 'Aldhpah HU', 'ABYAN-RASAD-ALDHPAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحنشي', 'Alhnshi HU', 'ABYAN-RASAD-ALHNSHIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخضراء', 'Alkhadra HU', 'ABYAN-RASAD-ALKHADRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المشوشي', 'Almshwshi HU', 'ABYAN-RASAD-ALMSHWSHIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العمري', 'Alomari HC', 'ABYAN-RASAD-ALOMARIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصفاه', 'Alsfaah HU', 'ABYAN-RASAD-ALSFAAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشعب', 'Alshap HU', 'ABYAN-RASAD-ALSHAPHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الوطح', 'Alwtah HU', 'ABYAN-RASAD-ALWTAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحمومة', 'Hamumh HU', 'ABYAN-RASAD-HAMUMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي هرمان', 'Harman HC', 'ABYAN-RASAD-HARMANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل السعدي', 'Jabal As Sadi HU', 'ABYAN-RASAD-JABALASSAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الموصف', 'Maosaf HU', 'ABYAN-RASAD-MAOSAFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة رصد', 'Maternity & Childhood Cente Rasad', 'ABYAN-RASAD-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قرية ناصر', 'Qriat Nassr HU', 'ABYAN-RASAD-QRIATNASSR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رهوة السوق', 'Rahwat As Sook HU', 'ABYAN-RASAD-RAHWATASSO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رخمة', 'Rkhmh HU', 'ABYAN-RASAD-RKHMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي شعب البارع', 'Shaep Albara  HC', 'ABYAN-RASAD-SHAEPALBAR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-RASAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه حطاط', 'Alhtat HU', 'ABYAN-SARAR-ALHTATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امها حمه', 'Amha Hamah HU', 'ABYAN-SARAR-AMHAHAMAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه عمران', 'Amran HU', 'ABYAN-SARAR-AMRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امسدارة', 'Amsdarh HU', 'ABYAN-SARAR-AMSDARHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حمة (أسفل امها)', 'Hamah (Asfl Amha) HU', 'ABYAN-SARAR-HAMAH(ASFL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه قرض', 'Karadh HU', 'ABYAN-SARAR-KARADHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه كلسام', 'Klsam HU', 'ABYAN-SARAR-KLSAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحة الانجابية سرار', 'Maternity & Childhood Center Sarar', 'ABYAN-SARAR-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شوضه', 'Shwdhah HU', 'ABYAN-SARAR-SHWDHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SARAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العرقة', 'Alarqh HU', 'ABYAN-SIBAH-ALARQHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصعيد', 'Alssaid HU', 'ABYAN-SIBAH-ALSSAIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ظبه', 'Dubah HU', 'ABYAN-SIBAH-DUBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حدق', 'Hadag HU', 'ABYAN-SIBAH-HADAGHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة سباح', 'Maternity & Childhood HC Sibah', 'ABYAN-SIBAH-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية طسة', 'Tasah HU', 'ABYAN-SIBAH-TASAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-SIBAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الطميسي', 'Al Tumaisi HU', 'ABYAN-ZINGIB-ALTUMAISIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عمودية', 'Amodiah HU', 'ABYAN-ZINGIB-AMODIAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشيخ عبدالله', 'Shaik Abdullah HU', 'ABYAN-ZINGIB-SHAIKABDUL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الشيخ سالم', 'Shaik Salem HU', 'ABYAN-ZINGIB-SHAIKSALEM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة بزنجبار', 'Zungobar Maternity & Childhood Center', 'ABYAN-ZINGIB-ZUNGOBARMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى زنجبار', 'Zunjopar H', 'ABYAN-ZINGIB-ZUNJOPARH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ABYAN-ZINGIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفارسي', 'AL Farisi HC', 'ADEN-ALBURA-ALFARISIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي البريقة', 'Alburaika Health Complex', 'ADEN-ALBURA-ALBURAIKAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحسوة', 'Alhaswa HC', 'ADEN-ALBURA-ALHASWAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الخيسة', 'Alkhisa HC', 'ADEN-ALBURA-ALKHISAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عمران', 'Amran HC', 'ADEN-ALBURA-AMRANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بئراحمد', 'Be''ar Ahmed HC', 'ADEN-ALBURA-BE''''ARAHME' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي فقم', 'Fukm HC', 'ADEN-ALBURA-FUKMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القلوعة بير أحمد', 'Kalloa''a Be''ar Ahmed HC', 'ADEN-ALBURA-KALLOA''''AB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي مدينة الشعب', 'Madinat Alsha''ab health complex', 'ADEN-ALBURA-MADINATALS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى مصافي عدن', 'Masafi Aden H', 'ADEN-ALBURA-MASAFIADEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى صلاح الدين', 'Salah Eldeen Hospital', 'ADEN-ALBURA-SALAHELDEE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALBURA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي القاهرة', 'Alkahera health complex', 'ADEN-ALMANS-ALKAHERAHE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMANS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الصيدلية المركزية', 'Central pharmacy', 'ADEN-ALMANS-CENTRALPHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMANS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي حاشد', 'Hashed Health Complex', 'ADEN-ALMANS-HASHEDHEAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMANS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي كابوتا (بئر فضل)', 'Kabota Health  complex', 'ADEN-ALMANS-KABOTAHEAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMANS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الرعاية الصحية الأولية', 'Primary Health Care HC', 'ADEN-ALMANS-PRIMARYHEA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMANS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي للصحة الإنجابية', 'Reporductive HC', 'ADEN-ALMUAL-REPORDUCTI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ALMUAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عبدالقوي', 'Abdulkawy HC', 'ADEN-ASHSHA-ABDULKAWYH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي كود العثماني', 'Alkawd Alothmani Hc', 'ADEN-ASHSHA-ALKAWDALOT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الممدارة', 'Almemdara  HC', 'ADEN-ASHSHA-ALMEMDARAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الصداقة التعليمي العام', 'Alsadaqa teaching hospital', 'ADEN-ASHSHA-ALSADAQATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي الشيخ عثمان', 'Alshaikh Otman health complex', 'ADEN-ASHSHA-ALSHAIKHOT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي المحاريق', 'Maharik HC', 'ADEN-ASHSHA-MAHARIKHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز ماري ستوبس', 'Marie Stopes Center', 'ADEN-ASHSHA-MARIESTOPE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفتح', 'Al Fath HC', 'ADEN-ATTAWA-ALFATHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ATTAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القلوعة', 'Alkalloa''a HC', 'ADEN-ATTAWA-ALKALLOA''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ATTAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي التواهي', 'Altwahi Health Complex', 'ADEN-ATTAWA-ALTWAHIHEA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ATTAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحة الانجابية حي الثورة', 'Hai Althawra maternity and childhood center', 'ADEN-ATTAWA-HAIALTHAWR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-ATTAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي القطيع', 'Alkatee''e health complex', 'ADEN-CRAITE-ALKATEE''''E' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-CRAITE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع الصحي الميدان', 'Almaidan Health Complex', 'ADEN-CRAITE-ALMAIDANHE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-CRAITE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الشعب التوليدي', 'Alsha''ab Obestitric Center', 'ADEN-CRAITE-ALSHA''''ABO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-CRAITE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بازرعه', 'Bazraeih HC', 'ADEN-CRAITE-BAZRAEIHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-CRAITE' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي اللحوم', 'Al Lehom HC', 'ADEN-DARSAD-ALLEHOMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-DARSAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السلام', 'Al salam HU', 'ADEN-DARSAD-ALSALAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-DARSAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز البساتين الطاهري', 'Albasateen Al taheri HC', 'ADEN-DARSAD-ALBASATEEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-DARSAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العماد', 'Alemad HC', 'ADEN-DARSAD-ALEMADHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-DARSAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مجمع دار سعد الصحي', 'Dar Sa''ad complex', 'ADEN-DARSAD-DARSA''''ADC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-DARSAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العريش', 'Alareesh HC', 'ADEN-KHURMA-ALAREESHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-KHURMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المجمع  الصحي خورمكسر', 'Khurmaksar health complex', 'ADEN-KHURMA-KHURMAKSAR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-KHURMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الكويت الصحي النموذجي (النصر)- مركز الطوارى التوليدية', 'Kuwait (AlNasr) HC - Obstetric Emergency HC', 'ADEN-KHURMA-KUWAIT(ALN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-KHURMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الهلال الاحمر اليمني', 'Yemeni Red Cresent  Center', 'ADEN-KHURMA-YEMENIREDC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ADEN-KHURMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  العريف', 'Al Arieef HC', 'ALBAYD-NA''''MAN-ALARIEEFHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALBAYD-NA''MAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية البديع', 'Al Badai HU', 'ALBAYD-NA''''MAN-ALBADAIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALBAYD-NA''MAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية حصير الجار', 'Al Haser al Har HU', 'ALBAYD-NA''''MAN-ALHASERALH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALBAYD-NA''MAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  الساحة', 'Al sahah HC', 'ALBAYD-NA''''MAN-ALSAHAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALBAYD-NA''MAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عراء', 'Araa Numan HC', 'ALBAYD-NA''''MAN-ARAANUMANH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALBAYD-NA''MAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الزند', 'Al Zand HU', 'ALDHAL-ADDHAL-ALZANDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العقبة', 'Alaqabh HU', 'ALDHAL-ADDHAL-ALAQABHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي البجح', 'Albjh HC', 'ALDHAL-ADDHAL-ALBJHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الضبيات', 'Aldhbiat HC', 'ALDHAL-ADDHAL-ALDHBIATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العشري', 'Aleshary HU', 'ALDHAL-ADDHAL-ALESHARYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفجرة', 'Alfjrh HU', 'ALDHAL-ADDHAL-ALFJRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجليلة', 'Aljalilah HU', 'ALDHAL-ADDHAL-ALJALILAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المركولة', 'Almrkulh HU', 'ALDHAL-ADDHAL-ALMRKULHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النجد حجر', 'Alnajd Hajr HU', 'ALDHAL-ADDHAL-ALNAJDHAJR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى النصر الضالع', 'Alnassr H', 'ALDHAL-ADDHAL-ALNASSRH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الردوع', 'Alrodo''a HU', 'ALDHAL-ADDHAL-ALRODO''''AH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الركبة', 'Alrukbah HU', 'ALDHAL-ADDHAL-ALRUKBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السرافي', 'Alsrafi HU', 'ALDHAL-ADDHAL-ALSRAFIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الطفوئ', 'Altfwaa HU', 'ALDHAL-ADDHAL-ALTFWAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الوعرة', 'Alwarah HU', 'ALDHAL-ADDHAL-ALWARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشعب', 'Asha''ab HU', 'ALDHAL-ADDHAL-ASHA''''ABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبيل السوق', 'Hapail Alsowq HU', 'ALDHAL-ADDHAL-HAPAILALSO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حازة الخلاقي', 'Hazat Alkhulaqi HU', 'ALDHAL-ADDHAL-HAZATALKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي لكمة الدوكي', 'Lakamah Aldouqi  HC', 'ALDHAL-ADDHAL-LAKAMAHALD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لكمة صلاح', 'Lkmh Slah HU', 'ALDHAL-ADDHAL-LKMHSLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سوق', 'Sooq HU', 'ALDHAL-ADDHAL-SOOQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثوبه', 'Thawbah HU', 'ALDHAL-ADDHAL-THAWBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زبيد', 'Zabid HU', 'ALDHAL-ADDHAL-ZABIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ADDHAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اعمور', 'Aamwr HU', 'ALDHAL-ALAZAR-AAMWRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عباب', 'Abab HU', 'ALDHAL-ALAZAR-ABABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عدن حمادة', 'Aden Hmadh HC', 'ALDHAL-ALAZAR-ADENHMADHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية أجوه', 'Ajwah HU', 'ALDHAL-ALAZAR-AJWAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحبلة', 'Al Hablah HU', 'ALDHAL-ALAZAR-ALHABLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الهجرة', 'Al Higrah HU', 'ALDHAL-ALAZAR-ALHIGRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الازارق ( ذي الجلال )', 'Alazarq HC', 'ALDHAL-ALAZAR-ALAZARQHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدرب', 'Aldrb HU', 'ALDHAL-ALAZAR-ALDRBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحقل', 'Alhaql HC', 'ALDHAL-ALAZAR-ALHAQLHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعفاري', 'Almafari Hourh HU', 'ALDHAL-ALAZAR-ALMAFARIHO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بلد اهل علي', 'Bld Ahl Ali HU', 'ALDHAL-ALAZAR-BLDAHLALIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حورة غنية', 'Ghnih Hourh HU', 'ALDHAL-ALAZAR-GHNIHHOURH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل عواس', 'Jabl Awas HU', 'ALDHAL-ALAZAR-JABLAWASHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قرض', 'Qradh HU', 'ALDHAL-ALAZAR-QRADHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه شان', 'Shaan HU', 'ALDHAL-ALAZAR-SHAANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية طبقين', 'Tapqeen HU', 'ALDHAL-ALAZAR-TAPQEENHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي تورصه', 'Turssh HC', 'ALDHAL-ALAZAR-TURSSHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALAZAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عدينة', 'Adinh HU', 'ALDHAL-ALHUSS-ADINHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العنسي', 'Al Ansi HU', 'ALDHAL-ALHUSS-ALANSIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصرفة', 'Al Sarfah HU', 'ALDHAL-ALHUSS-ALSARFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الضاهرة', 'Aldhahrh HU', 'ALDHAL-ALHUSS-ALDHAHRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحصين', 'Alhassin HC', 'ALDHAL-ALHUSS-ALHASSINHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية لخربة', 'Alkhrph Shka HU', 'ALDHAL-ALHUSS-ALKHRPHSHK' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المرافدة', 'Almrafdh HU', 'ALDHAL-ALHUSS-ALMRAFDHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القبه', 'Alquph HU', 'ALDHAL-ALHUSS-ALQUPHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ارحب', 'Arhab HU', 'ALDHAL-ALHUSS-ARHABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حبيل الزريبة', 'Habil Alzribh HC', 'ALDHAL-ALHUSS-HABILALZRI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة حرير', 'Harir Maternity & Childhood Center', 'ALDHAL-ALHUSS-HARIRMATER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي خله', 'Khlh HC', 'ALDHAL-ALHUSS-KHLHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية خوبر', 'Khwbr HU', 'ALDHAL-ALHUSS-KHWBRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي لكمة لشعوب', 'Lakamah Lasho''ub HC', 'ALDHAL-ALHUSS-LAKAMAHLAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لكمة النوب', 'Lakamt An Nob HU', 'ALDHAL-ALHUSS-LAKAMTANNO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مرفد', 'Marfad HU', 'ALDHAL-ALHUSS-MARFADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مرات', 'Mrat HU', 'ALDHAL-ALHUSS-MRATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صرارة', 'Srarh Shka HU', 'ALDHAL-ALHUSS-SRARHSHKAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ALHUSS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ال انعم', 'Aal Anam HU', 'ALDHAL-ASHSHU-AALANAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة', 'Alauapl Maternity & Childhood Center', 'ALDHAL-ASHSHU-ALAUAPLMAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجعافر', 'Alja''afer HU', 'ALDHAL-ASHSHU-ALJA''''AFER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي المضو', 'Almdhw HC', 'ALDHAL-ASHSHU-ALMDHWHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القهرة', 'Alqhrah HU', 'ALDHAL-ASHSHU-ALQHRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القزعة', 'Alqzah HU', 'ALDHAL-ASHSHU-ALQZAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرباط', 'Alrubat HC', 'ALDHAL-ASHSHU-ALRUBATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ارضة لقروع', 'Aradhat Lagroaa HU', 'ALDHAL-ASHSHU-ARADHATLAG' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشرف', 'As Shaeraf HU', 'ALDHAL-ASHSHU-ASSHAERAFH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصلئة', 'Asal''a HU', 'ALDHAL-ASHSHU-ASAL''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بكئين', 'Bakaain HU', 'ALDHAL-ASHSHU-BAKAAINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بخال', 'Bkhal  HU', 'ALDHAL-ASHSHU-BKHALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني مسلم', 'Bni Muslim HU', 'ALDHAL-ASHSHU-BNIMUSLIMH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل القضاة', 'Japal Alqudhah HU', 'ALDHAL-ASHSHU-JAPALALQUD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية  لنجود', 'Lanjoud HU', 'ALDHAL-ASHSHU-LANJOUDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى لصبور الريفي', 'Lasbowr H', 'ALDHAL-ASHSHU-LASBOWRH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي لودية', 'Ludih HC', 'ALDHAL-ASHSHU-LUDIHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مكلان', 'Meklan HU', 'ALDHAL-ASHSHU-MEKLANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية راغب', 'Ragheb HU', 'ALDHAL-ASHSHU-RAGHEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  صبر الشرف البلاعس', 'Sharaf Albalaes HC', 'ALDHAL-ASHSHU-SHARAFALBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-ASHSHU' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه عبر', 'Abr HU', 'ALDHAL-JAHAF-ABRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الأكمة', 'Al Akamah HC', 'ALDHAL-JAHAF-ALAKAMAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحلجوم', 'Al Hljom HU', 'ALDHAL-JAHAF-ALHLJOMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحيب', 'Al hib HU', 'ALDHAL-JAHAF-ALHIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العزله', 'Alazlh HC', 'ALDHAL-JAHAF-ALAZLHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البياضة', 'Albiadha HU', 'ALDHAL-JAHAF-ALBIADHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه المداد', 'Almdad HU', 'ALDHAL-JAHAF-ALMDADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الشيمه', 'Alshimh HU', 'ALDHAL-JAHAF-ALSHIMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه السلقه', 'Alslqh HU', 'ALDHAL-JAHAF-ALSLQHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السويداء', 'Alswaida HU', 'ALDHAL-JAHAF-ALSWAIDAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بني خلف', 'Bani Kalf HU', 'ALDHAL-JAHAF-BANIKALFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه قرنه', 'Garnah HU', 'ALDHAL-JAHAF-GARNAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه حودين', 'Hudin HU', 'ALDHAL-JAHAF-HUDINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الريفي جحاف', 'Jahaf Rurai H', 'ALDHAL-JAHAF-JAHAFRURAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله سرير', 'Maternity & Childhood Center Srir', 'ALDHAL-JAHAF-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي صليف - بني سعيد', 'Saleef HC - Bani Saeed', 'ALDHAL-JAHAF-SALEEFHC-B' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه شران', 'Shran HU', 'ALDHAL-JAHAF-SHRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-JAHAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكتمي', 'ALqatamy HU', 'ALDHAL-QA''''ATA-ALQATAMYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجرب', 'Al Garb HU', 'ALDHAL-QA''''ATA-ALGARBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحميراء', 'Al Hmerui HU', 'ALDHAL-QA''''ATA-ALHMERUIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخبل', 'Al Khabl HU', 'ALDHAL-QA''''ATA-ALKHABLHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المدرج', 'Al Madraj HU', 'ALDHAL-QA''''ATA-ALMADRAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المروي', 'Al Maroy HU', 'ALDHAL-QA''''ATA-ALMAROYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القفله', 'Al Quflah HU', 'ALDHAL-QA''''ATA-ALQUFLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العتبات', 'Alatbat HU', 'ALDHAL-QA''''ATA-ALATBATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفاخر', 'Alfakhr HC', 'ALDHAL-QA''''ATA-ALFAKHRHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الجبارة', 'Algabarah HC', 'ALDHAL-QA''''ATA-ALGABARAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية القدام', 'Alqudam HU', 'ALDHAL-QA''''ATA-ALQUDAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى السلام', 'Alslam H', 'ALDHAL-QA''''ATA-ALSLAMH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الريبي', 'Arabi', 'ALDHAL-QA''''ATA-ARABI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ظفي', 'Dhifi HU', 'ALDHAL-QA''''ATA-DHIFIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الطوارى التوليدية', 'Emergency Obestitric HC', 'ALDHAL-QA''''ATA-EMERGENCYO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى غول الديمة', 'Ghoul Aldimh Hospital', 'ALDHAL-QA''''ATA-GHOULALDIM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حليف', 'Hlif HU', 'ALDHAL-QA''''ATA-HLIFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حمر السادة', 'Humr Alsaadah HU', 'ALDHAL-QA''''ATA-HUMRALSAAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحي قراوة', 'Qrawh HU', 'ALDHAL-QA''''ATA-QRAWHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ريشان', 'Rechan HU', 'ALDHAL-QA''''ATA-RECHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيو شقران', 'Shqran HU', 'ALDHAL-QA''''ATA-SHQRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية شخب', 'shkhp HU', 'ALDHAL-QA''''ATA-SHKHPHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALDHAL-QA''ATA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة ابو زهر الصحية', 'Abu Zahr HU', 'ALHUDA-ALKHAW-ABUZAHRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المراشده', 'Al Marashdah HU', 'ALHUDA-ALKHAW-ALMARASHDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البابلي', 'Al bably HU', 'ALHUDA-ALKHAW-ALBABLYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة الجشة الصحية', 'Al jasha Hu', 'ALHUDA-ALKHAW-ALJASHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة القطابا الصحية', 'Alkataba HU', 'ALHUDA-ALKHAW-ALKATABAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الجديد', 'Alkhukha aljadeed HC', 'ALHUDA-ALKHAW-ALKHUKHAAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة الوعرة الصحية', 'Alwara HU', 'ALHUDA-ALKHAW-ALWARAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'بسمة أمل', 'Basma Amal', 'ALHUDA-ALKHAW-BASMAAMAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة دار ناجي الصحية', 'Dar Naji HU', 'ALHUDA-ALKHAW-DARNAJIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة (مركز الطوارئ)', 'Emergncy Obestitric  HC', 'ALHUDA-ALKHAW-EMERGNCYOB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركزحائط الكنزل الصحية', 'Haadh Al Kanzal HU', 'ALHUDA-ALKHAW-HAADHALKAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الملك سلمان', 'King Salman HC', 'ALHUDA-ALKHAW-KINGSALMAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة موشج الصحية', 'Mushaj HU', 'ALHUDA-ALKHAW-MUSHAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي اللاجئين', 'Refugee HC', 'ALHUDA-ALKHAW-REFUGEEHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة الضاحية', 'وحدة الضاحية', 'ALHUDA-ALKHAW-وحدةالضاحي' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ALKHAW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الحيمة الساحلية الصحي', 'Alhaima HC', 'ALHUDA-ATTUHA-ALHAIMAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-ATTUHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة االصحية الجمادي', 'Al Jamadi HU', 'ALHUDA-HAYS-ALJAMADIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجرة', 'Al Jarah HU', 'ALHUDA-HAYS-ALJARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الكدحة', 'Al Kadahah HU', 'ALHUDA-HAYS-ALKADAHAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الرون', 'Al Rawn HU', 'ALHUDA-HAYS-ALRAWNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه المجاعشه', 'AlMgasha', 'ALHUDA-HAYS-ALMGASHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الاكبر', 'Alakbar HU', 'ALHUDA-HAYS-ALAKBARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفش', 'Alfash HU', 'ALHUDA-HAYS-ALFASHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة    الصحية القلمة', 'Alkalma HU', 'ALHUDA-HAYS-ALKALMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'االوحدة الصحيه النفسة', 'Alnafsa HU', 'ALHUDA-HAYS-ALNAFSAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الرباط', 'Alrebat HU', 'ALHUDA-HAYS-ALREBATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه السبعه', 'Alsaba''a HU', 'ALHUDA-HAYS-ALSABA''''AH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الشعوب', 'Alshuob HU', 'ALHUDA-HAYS-ALSHUOBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بييت الحشاش', 'Bait Alhashash HU', 'ALHUDA-HAYS-BAITALHASH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه ظمي', 'Dhami HU', 'ALHUDA-HAYS-DHAMIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حيس الريفي', 'Hais rural Hospital', 'ALHUDA-HAYS-HAISRURALH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه محل الربيع', 'Mahlalrabe''e HU', 'ALHUDA-HAYS-MAHLALRABE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALHUDA-HAYS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجمعية', 'Al Jameia HU', 'ALMAHA-ALGHAY-ALJAMEIAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العبري', 'Alabree HU', 'ALMAHA-ALGHAY-ALABREEHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الغيضة', 'Alghidha H', 'ALMAHA-ALGHAY-ALGHIDHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هروت', 'Harot HU', 'ALMAHA-ALGHAY-HAROTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية مظريك', 'Mdhrik HU', 'ALMAHA-ALGHAY-MDHRIKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية محيفيف', 'Mhifif HU', 'ALMAHA-ALGHAY-MHIFIFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نشطون', 'Nashtoon HU', 'ALMAHA-ALGHAY-NASHTOONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفيدمي', 'alfidmy HC', 'ALMAHA-ALGHAY-ALFIDMYHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALGHAY' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العيص', 'Alaiss HC', 'ALMAHA-ALMASI-ALAISSHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALMASI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دحسويس', 'Dhsous HU', 'ALMAHA-ALMASI-DHSOUSHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALMASI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حساي', 'Hsay HU', 'ALMAHA-ALMASI-HSAYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALMASI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العيص الهابطية', 'Laiss HU', 'ALMAHA-ALMASI-LAISSHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALMASI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رخوت', 'Rkhout HU', 'ALMAHA-ALMASI-RKHOUTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-ALMASI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه اثوب', 'Athoub HU', 'ALMAHA-HAT-ATHOUBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HAT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي حات', 'Hat HC', 'ALMAHA-HAT-HATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HAT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحده الصحيه دمقوت', 'Dmqout HU', 'ALMAHA-HAWF-DMQOUTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HAWF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حوف الريفي', 'Houf H', 'ALMAHA-HAWF-HOUFH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HAWF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الوادي', 'Alwadi HU', 'ALMAHA-HUSWAI-ALWADIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HUSWAI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حصوين الريفي', 'Huswain Rural Hospital', 'ALMAHA-HUSWAI-HUSWAINRUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HUSWAI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي صقر', 'Saqar HC', 'ALMAHA-HUSWAI-SAQARHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-HUSWAI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحده الصحيه الواسطه', 'Alwasth HU', 'ALMAHA-MAN''''AR-ALWASTHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ارنبوت', 'Arnabout HC', 'ALMAHA-MAN''''AR-ARNABOUTHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ابيلم', 'Ibeelam HU', 'ALMAHA-MAN''''AR-IBEELAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي منعر', 'Manaar HC', 'ALMAHA-MAN''''AR-MANAARHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحده صحيه مرعيت', 'Mrait HU', 'ALMAHA-MAN''''AR-MRAITHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية توف', 'Twf HU', 'ALMAHA-MAN''''AR-TWFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحده صحيه وادي قات', 'Wadi Qat HU', 'ALMAHA-MAN''''AR-WADIQATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-MAN''AR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي كروي', 'Karwi Khshn HC', 'ALMAHA-QISHN-KARWIKHSHN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-QISHN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى قشن الريفي', 'Qshin Rural H', 'ALMAHA-QISHN-QSHINRURAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-QISHN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية درفات', 'Derfat HU', 'ALMAHA-SAYHUT-DERFATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-SAYHUT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رخوت الشرقية', 'Rakhout Alsharqeiah HU', 'ALMAHA-SAYHUT-RAKHOUTALS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-SAYHUT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى  سيحوت', 'Sihout H', 'ALMAHA-SAYHUT-SIHOUTH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-SAYHUT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي فوجيت', 'Foujeet HC', 'ALMAHA-SHAHAN-FOUJEETHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-SHAHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز السلطان قابوس الصحي بشحن', 'Sultan Qaboos HC', 'ALMAHA-SHAHAN-SULTANQABO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMAHA-SHAHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغريفتين', 'Alghurifatain HU', 'ALMUKA-ADDIS-ALGHURIFAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هبورك', 'Habork HU', 'ALMUKA-ADDIS-HABORKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز  حلفون الصحي', 'Halfon HC', 'ALMUKA-ADDIS-HALFONHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفولة', 'Maternity & Childhood Center', 'ALMUKA-ADDIS-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثوبان', 'Thawban HU', 'ALMUKA-ADDIS-THAWBANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية يضغط', 'Yadhghud HU', 'ALMUKA-ADDIS-YADHGHUDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADDIS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه اللصبيب', 'AL lasieb HU', 'ALMUKA-ADHDHL-ALLASIEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركزالضليعة الصحي', 'Aldhulaia''a HC', 'ALMUKA-ADHDHL-ALDHULAIA''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالحجلين', 'Alhajlain HU', 'ALMUKA-ADHDHL-ALHAJLAINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالكريف', 'Alkareef HU', 'ALMUKA-ADHDHL-ALKAREEFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالقويع', 'Alkwai''e HU', 'ALMUKA-ADHDHL-ALKWAI''''EH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المسيل', 'Almaseel HU', 'ALMUKA-ADHDHL-ALMASEELHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالنجيدين', 'Alnajdain HU', 'ALMUKA-ADHDHL-ALNAJDAINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالروضة', 'Alrawdha HU', 'ALMUKA-ADHDHL-ALRAWDHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحد الصحية بالشعبات', 'Alsha''abat HU', 'ALMUKA-ADHDHL-ALSHA''''ABA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عتود', 'Atoud HU', 'ALMUKA-ADHDHL-ATOUDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ببراورة', 'Brawah HU', 'ALMUKA-ADHDHL-BRAWAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بسوط ال علي الجربة', 'Sawt Al Ali HU', 'ALMUKA-ADHDHL-SAWTALALIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بسوط المشاجر(قدة)', 'Sawt almashajer HU', 'ALMUKA-ADHDHL-SAWTALMASH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ADHDHL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه عضد', 'Adhad HU', 'ALMUKA-ALMUKA-ADHADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحوطه', 'Al Hodah HU', 'ALMUKA-ALMUKA-ALHODAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده  الصحيه الحجيره', 'Al HojairahHU', 'ALMUKA-ALMUKA-ALHOJAIRAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الخربه', 'Alkharba HU', 'ALMUKA-ALMUKA-ALKHARBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه اللصب', 'Allusb HU', 'ALMUKA-ALMUKA-ALLUSBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه المذينب', 'Almadhib HU', 'ALMUKA-ALMUKA-ALMADHIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بين الجبال', 'Bainaljebal HU', 'ALMUKA-ALMUKA-BAINALJEBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه خليف بن يسلم', 'Khalif Yaslam HU', 'ALMUKA-ALMUKA-KHALIFYASL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه المسنى', 'Masna HU', 'ALMUKA-ALMUKA-MASNAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه رأس محل', 'Rasmahal HU', 'ALMUKA-ALMUKA-RASMAHALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه شهوره', 'Shahwra HU', 'ALMUKA-ALMUKA-SHAHWRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه ثله العليا', 'Talat Alolya HU', 'ALMUKA-ALMUKA-TALATALOLY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه ثلة باعمر', 'Thlat Baomar HU', 'ALMUKA-ALMUKA-THLATBAOMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه وادي حمم', 'Wadihamam HU', 'ALMUKA-ALMUKA-WADIHAMAMH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي 30 نوفمبر لطب الاسره', '30 November Family Health Center', 'ALMUKA-ALMUKA-30NOVEMBER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحة 40 شقة', '40 Shakah HU', 'ALMUKA-ALMUKA-40SHAKAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الانشاءات', 'Al Anshaat HC', 'ALMUKA-ALMUKA-ALANSHAATH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحرشيات لطب الاسرة', 'Al Hirshiat Family Health Center', 'ALMUKA-ALMUKA-ALHIRSHIAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الخزان', 'Al Khazzan HC', 'ALMUKA-ALMUKA-ALKHAZZANH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي المنوره', 'Al Munawarah HC', 'ALMUKA-ALMUKA-ALMUNAWARA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصديق الخيري', 'Al Seddik Alkhairi Center', 'ALMUKA-ALMUKA-ALSEDDIKAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز النور الخيري', 'Al Seddik Alnoor Center', 'ALMUKA-ALMUKA-ALNOORAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي البقرين', 'Al bakareen HC', 'ALMUKA-ALMUKA-ALBAKAREEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الربوة بخلف', 'Al-Rabwa Center', 'ALMUKA-ALMUKA-AL-RABWACE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العيص', 'Alais HU', 'ALMUKA-ALMUKA-ALAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الغليله', 'Alghalila HU', 'ALMUKA-ALMUKA-ALGHALILAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي علي بن ابي طالب لطب الاسره', 'Ali Bin Abi Taleb Family Health Center', 'ALMUKA-ALMUKA-ALIBINABIT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الطويلة', 'At Tawilah HU', 'ALMUKA-ALMUKA-ATTAWILAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي باعبود لطب الاسرة', 'Baabod Family Health Center', 'ALMUKA-ALMUKA-BAABODFAMI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركر الصحي بديري', 'Bdiree HC', 'ALMUKA-ALMUKA-BDIREEHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بويش', 'Bwaish HC', 'ALMUKA-ALMUKA-BWAISHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  فوه القديمة لطب الاسرة', 'Fawah alkadima Family Health Center FCH', 'ALMUKA-ALMUKA-FAWAHALKAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي غرب الضيافه', 'Gharb Al Deafah HC', 'ALMUKA-ALMUKA-GHARBALDEA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي باسويد', 'Haft Baswaid HC', 'ALMUKA-ALMUKA-HAFTBASWAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حي المستقبل', 'Hai Al Mostakbal HC', 'ALMUKA-ALMUKA-HAIALMOSTA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حي النصر', 'Hai Al Nasser HC', 'ALMUKA-ALMUKA-HAIALNASSE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حي العمال', 'Hai Al Omal HC', 'ALMUKA-ALMUKA-HAIALOMALH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حي السلام', 'Haialsalam HC', 'ALMUKA-ALMUKA-HAIALSALAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حلة', 'Hallah HU', 'ALMUKA-ALMUKA-HALLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جول مسحه', 'Jawl Al Massha HC', 'ALMUKA-ALMUKA-JAWLALMASS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جول الشفاء', 'Jawl Alshifa HC', 'ALMUKA-ALMUKA-JAWLALSHIF' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي خلف', 'Khalaf HC', 'ALMUKA-ALMUKA-KHALAFHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي روكب لطب الاسره', 'Rawkab FHC', 'ALMUKA-ALMUKA-RAWKABFHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي شعب البادية', 'Shab al badiah HC', 'ALMUKA-ALMUKA-SHABALBADI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الجامعي لطب الاسره', 'University Family Health Center', 'ALMUKA-ALMUKA-UNIVERSITY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الجامعي للنساء والأطفال', 'University Women and Children Hospital', 'ALMUKA-ALMUKA-UNIVWCHOSP' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'جمعية رعاية الاسرة اليمنية', 'Yemeni Family Care Association', 'ALMUKA-ALMUKA-YEMENIFAMI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ALMUKA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي البر والاحسان بالحافه', 'ALberwalehsan blhafa HC', 'ALMUKA-ARRAYD-ALBERWALEH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المحرم', 'Al Mahram HU', 'ALMUKA-ARRAYD-ALMAHRAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المنازح', 'Al Mnazah HU', 'ALMUKA-ARRAYD-ALMNAZAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه المصينعه', 'Almusaine''a HU', 'ALMUKA-ARRAYD-ALMUSAINE''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الريدة الشرقيه', 'Alraida Alasharkia H', 'ALMUKA-ARRAYD-ALRAIDAALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه شخاوي', 'Alshakhawi HU', 'ALMUKA-ARRAYD-ALSHAKHAWI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عسد الفايه', 'Asad Alfaya HU', 'ALMUKA-ARRAYD-ASADALFAYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عسد الجبل', 'Asad Aljabal HC', 'ALMUKA-ARRAYD-ASADALJABA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدةالصحيه بدش', 'Dash HU', 'ALMUKA-ARRAYD-DASHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ظبق هزاول', 'Dhabak Hazawel HU', 'ALMUKA-ARRAYD-DHABAKHAZA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه حبظ', 'Habt HU', 'ALMUKA-ARRAYD-HABTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حضاتهم', 'Hadhathm HC', 'ALMUKA-ARRAYD-HADHATHMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية خاشيم', 'Khashim HU', 'ALMUKA-ARRAYD-KHASHIMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه كروشم', 'Krosham HU', 'ALMUKA-ARRAYD-KROSHAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي قصيعر', 'Kusaie''er HC', 'ALMUKA-ARRAYD-KUSAIE''''ER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه معبر', 'Ma''abar HU', 'ALMUKA-ARRAYD-MA''''ABARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده االصحية مهينم', 'Muhainem HU', 'ALMUKA-ARRAYD-MUHAINEMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه رغدون', 'Raghdon HU', 'ALMUKA-ARRAYD-RAGHDONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه سرار', 'Sarar HU', 'ALMUKA-ARRAYD-SARARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  تحت الطريق', 'That altarik HU', 'ALMUKA-ARRAYD-THATALTARI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ARRAYD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه 180 شقه', '180 apartment HU', 'ALMUKA-ASHSHI-180APARTME' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعدي', 'AL Mamdi HU', 'ALMUKA-ASHSHI-ALMAMDIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عرف', 'ARAF HC', 'ALMUKA-ASHSHI-ARAFHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العيص', 'Alais HU', 'ALMUKA-ASHSHI-ALAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحامي', 'Alhami HC', 'ALMUKA-ASHSHI-ALHAMIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية المحط', 'Almaht HU', 'ALMUKA-ASHSHI-ALMAHTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المقد', 'Almakd HU', 'ALMUKA-ASHSHI-ALMAKDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بالمنصوره', 'Almansoura HU', 'ALMUKA-ASHSHI-ALMANSOURA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الرشاد', 'Alrashad HU', 'ALMUKA-ASHSHI-ALRASHADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الرحمن', 'Ar Rahman HU', 'ALMUKA-ASHSHI-ARRAHMANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بن جوبان', 'Bin Guban HC', 'ALMUKA-ASHSHI-BINGUBANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مقد العبية', 'Makdalabya HU', 'ALMUKA-ASHSHI-MAKDALABYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركزاللأمومه والطفوله الشحر', 'Maternity & Childhood HC Ash Shihr', 'ALMUKA-ASHSHI-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه  معيان المساجده', 'Meyan Almasajeda HU', 'ALMUKA-ASHSHI-MEYANALMAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تباله', 'Tabala HU', 'ALMUKA-ASHSHI-TABALAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زغفه', 'Zaghafah HU', 'ALMUKA-ASHSHI-ZAGHAFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-ASHSHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشرج', 'Alsharj HU', 'ALMUKA-BROMMA-ALSHARJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البندر', 'Bandar HU', 'ALMUKA-BROMMA-BANDARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بروم', 'Baroum HC', 'ALMUKA-BROMMA-BAROUMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية باتيس', 'Batais HU', 'ALMUKA-BROMMA-BATAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي غيضة البهيش', 'Ghaidhat buhaish HC', 'ALMUKA-BROMMA-GHAIDHATBU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  الحيلة', 'Hila HU', 'ALMUKA-BROMMA-HILAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حصيحصة', 'Husasaha HU', 'ALMUKA-BROMMA-HUSASAHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة السفال', 'Maifa''a maternity and childhood center', 'ALMUKA-BROMMA-MAIFA''''AMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ردفان', 'Radfan HU', 'ALMUKA-BROMMA-RADFANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي وادي المحمديين السفل', 'Wadi Almuhamdeein Altufl HC', 'ALMUKA-BROMMA-WADIALMUHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-BROMMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى القويره', 'AlGwayrah H', 'ALMUKA-DAW''''AN-ALGWAYRAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الهجرين التعاوني', 'Alhajrain H', 'ALMUKA-DAW''''AN-ALHAJRAINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه صبيخ', 'Alsubaikh HU', 'ALMUKA-DAW''''AN-ALSUBAIKHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بلجرات', 'Baljrat HU', 'ALMUKA-DAW''''AN-BALJRATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الخيري الصحي', 'Charity HU', 'ALMUKA-DAW''''AN-CHARITYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه حوفه', 'Hawfa HU', 'ALMUKA-DAW''''AN-HAWFAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه قيدون', 'Kaidon HU', 'ALMUKA-DAW''''AN-KAIDONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي لبنه بارشيد', 'Labna HC', 'ALMUKA-DAW''''AN-LABNAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى مقيبل بالجحي', 'Mukaibel Balhji H', 'ALMUKA-DAW''''AN-MUKAIBELBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه صيف', 'Rasif HU', 'ALMUKA-DAW''''AN-RASIFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه رباط باعشن', 'Rbat Ba''ashn HU', 'ALMUKA-DAW''''AN-RBATBA''''AS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-DAW''AN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عبدالله غريب', 'Abdullah Ghareeb HU', 'ALMUKA-GHAYLB-ABDULLAHGH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الهمة', 'Al Hemah HU', 'ALMUKA-GHAYLB-ALHEMAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العيون', 'Aleyoun HU', 'ALMUKA-GHAYLB-ALEYOUNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القارة', 'Alkara HC', 'ALMUKA-GHAYLB-ALKARAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الصداع', 'Alsada''a HC', 'ALMUKA-GHAYLB-ALSADA''''AH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية غيل الحالكة', 'Ghail Alhaleka HU', 'ALMUKA-GHAYLB-GHAILALHAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى غيل باوزير', 'Ghail Bawazeer H', 'ALMUKA-GHAYLB-GHAILBAWAZ' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كثيبة', 'Kotibah HU', 'ALMUKA-GHAYLB-KOTIBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالنقعة', 'Naka''a HU', 'ALMUKA-GHAYLB-NAKA''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رأس حويره', 'Rashwaira HU', 'ALMUKA-GHAYLB-RASHWAIRAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حباير', 'Sabayer HU', 'ALMUKA-GHAYLB-SABAYERHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي شحير', 'Shuhair HC', 'ALMUKA-GHAYLB-SHUHAIRHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي السناء (بريدة الجوهيين)', 'ALsana HC', 'ALMUKA-GHAYLB-ALSANAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بالعكده', 'Al Akad HU', 'ALMUKA-GHAYLB-ALAKADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العليب', 'Alaleeb HC', 'ALMUKA-GHAYLB-ALALEEBHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القرن', 'Alkarn HU', 'ALMUKA-GHAYLB-ALKARNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بالسيله', 'As Silah HU', 'ALMUKA-GHAYLB-ASSILAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى غيل بن يمين', 'Ghayl Bin yamin Hospital', 'ALMUKA-GHAYLB-GHAYLBINYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حصن ال الصعب', 'Hisn Alsa''ab HU', 'ALMUKA-GHAYLB-HISNALSA''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قاع ال عوض', 'Ka''a Alawadh HU', 'ALMUKA-GHAYLB-KA''''AALAWA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رحبة بن جنيد', 'Rahba Bin Junaid HU', 'ALMUKA-GHAYLB-RAHBABINJU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ريدة المعاره', 'Raydat Al Maarah  HC', 'ALMUKA-GHAYLB-RAYDATALMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه يوسن', 'Yosan HU', 'ALMUKA-GHAYLB-YOSANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ردهه', 'radha HU', 'ALMUKA-GHAYLB-RADHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-GHAYLB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عرس', 'Al Ars HU', 'ALMUKA-HAJR-ALARSHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة الجول', 'Al Gol - Maternity and Childhood Center', 'ALMUKA-HAJR-ALGOL-MATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العين', 'Aleyn HU', 'ALMUKA-HAJR-ALEYNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحوطة', 'Alhawta HU', 'ALMUKA-HAJR-ALHAWTAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخشعة', 'Alkhasha''ah HU', 'ALMUKA-HAJR-ALKHASHA''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القيمة', 'Alkima HU', 'ALMUKA-HAJR-ALKIMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المنتاق', 'Almantak HU', 'ALMUKA-HAJR-ALMANTAKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الصدارة', 'Alsadara HC', 'ALMUKA-HAJR-ALSADARAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية باقشيم', 'Bakashim HU', 'ALMUKA-HAJR-BAKASHIMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حصن باقروان', 'Hisn Bakrowan HU', 'ALMUKA-HAJR-HISNBAKROW' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جزول البلاد', 'Jazoul albelad HU', 'ALMUKA-HAJR-JAZOULALBE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جزول المعلاة', 'Jazoul ِHU', 'ALMUKA-HAJR-JAZOULِHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كحلان', 'Kahlan HU', 'ALMUKA-HAJR-KAHLANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كنينة شرج الراك', 'Kaninat sharjalrak HU', 'ALMUKA-HAJR-KANINATSHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قشن', 'Kishn HU', 'ALMUKA-HAJR-KISHNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية محمدة', 'Mahmada HU', 'ALMUKA-HAJR-MAHMADAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية روبة', 'Rawba HU', 'ALMUKA-HAJR-RAWBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي يون', 'Yon HC', 'ALMUKA-HAJR-YONHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-HAJR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الغمصه', 'Alghamsa HU', 'ALMUKA-YABUTH-ALGHAMSAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الجنينه', 'Aljanena HU', 'ALMUKA-YABUTH-ALJANENAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه العلا', 'Alola''a HU', 'ALMUKA-YABUTH-ALOLA''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الزيار', 'Alzyad HU', 'ALMUKA-YABUTH-ALZYADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كلب', 'Kalb HU', 'ALMUKA-YABUTH-KALBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه قارة الساده', 'Karat Alsada HU', 'ALMUKA-YABUTH-KARATALSAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مشاط للأمومة والطفولة', 'Mashat maternity and childhood HC', 'ALMUKA-YABUTH-MASHATMATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي يبعث', 'Yaba''ath HC', 'ALMUKA-YABUTH-YABA''''ATHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'ALMUKA-YABUTH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الدباء', 'Al Duba Health Center', 'LAHJ-ALHAWT-ALDUBAHEAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAWT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'هيئة مستشفى إبن خلدون', 'Ibn Khaldon Authority H', 'LAHJ-ALHAWT-IBNKHALDON' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAWT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة النموذجي الحوطة', 'Model Maternity & Childhood Center AL- Hawtah', 'LAHJ-ALHAWT-MODELMATER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAWT' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرداماء', 'Al Rdamaa HU', 'LAHJ-ALHAD-ALRDAMAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الحد الريفي', 'Alhad rural H', 'LAHJ-ALHAD-ALHADRURAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحصن', 'Alhasn HU', 'LAHJ-ALHAD-ALHASNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجناب', 'Aljanab HU', 'LAHJ-ALHAD-ALJANABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشرف', 'Asharaf HU', 'LAHJ-ALHAD-ASHARAFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ريشان', 'Rayshan HU', 'LAHJ-ALHAD-RAYSHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ريو الحصن', 'Ryo Alhisn HU', 'LAHJ-ALHAD-RYOALHISNH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ريو وسط الحيد', 'Ryo wasat alhad HU', 'LAHJ-ALHAD-RYOWASATAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خلاقة', 'khalaka HU', 'LAHJ-ALHAD-KHALAKAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALHAD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المضاربة العلياء', 'Al Madarebah AL Ulya HU', 'LAHJ-ALMADA-ALMADAREBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكديراء', 'Al kdiraa HU', 'LAHJ-ALMADA-ALKDIRAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القبيصة', 'Al kobisah HU', 'LAHJ-ALMADA-ALKOBISAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى العاره الريفي', 'Ala''ara rural H', 'LAHJ-ALMADA-ALA''''ARARU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفروخيه', 'Alfarokhyah HC', 'LAHJ-ALMADA-ALFAROKHYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحيمة', 'Alhaima HC', 'LAHJ-ALMADA-ALHAIMAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المضاربة السفلى', 'Almadhareba As Sufla HU', 'LAHJ-ALMADA-ALMADHAREB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المجزاع', 'Almajza''a HU', 'LAHJ-ALMADA-ALMAJZA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النابية', 'Alnabya HU', 'LAHJ-ALMADA-ALNABYAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرويس', 'Alrwais HU', 'LAHJ-ALMADA-ALRWAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السبيل', 'Alsabeel HU', 'LAHJ-ALMADA-ALSABEELHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي السدير', 'Alsadeer HC', 'LAHJ-ALMADA-ALSADEERHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصريح', 'Alsareeh HU', 'LAHJ-ALMADA-ALSAREEHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشط', 'Alshat rural H', 'LAHJ-ALMADA-ALSHATRURA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية السقياء', 'Alsukya HU', 'LAHJ-ALMADA-ALSUKYAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بطان', 'Batan HU', 'LAHJ-ALMADA-BATANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هقرة', 'Hkrah HU', 'LAHJ-ALMADA-HKRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هويرب', 'Hwaireb HU', 'LAHJ-ALMADA-HWAIREBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خور العميره', 'Khor Alomaira HU', 'LAHJ-ALMADA-KHORALOMAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تربهة', 'Turbahah HU', 'LAHJ-ALMADA-TURBAHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خرز', 'kharaz HU', 'LAHJ-ALMADA-KHARAZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMADA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجعشاني', 'Alja''ashani HU', 'LAHJ-ALMAFL-ALJA''''ASHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجبل الاعلى', 'Aljabal Alala HU', 'LAHJ-ALMAFL-ALJABALALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجربة', 'Aljerba HU', 'LAHJ-ALMAFL-ALJERBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى المفلحي الريفي', 'Almaflehi Rural H', 'LAHJ-ALMAFL-ALMAFLEHIR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السليماني', 'Alsulaimany HU', 'LAHJ-ALMAFL-ALSULAIMAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عثارة', 'Athara HU', 'LAHJ-ALMAFL-ATHARAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شيهج', 'Shahej HU', 'LAHJ-ALMAFL-SHAHEJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية طرف عثارة', 'Taraf Athara HU', 'LAHJ-ALMAFL-TARAFATHAR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية وادي بن جعفر', 'Wadi Ban Ja''afar HU', 'LAHJ-ALMAFL-WADIBANJA''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAFL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البكيرة', 'Al Bokirah HU', 'LAHJ-ALMAQA-ALBOKIRAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدهمشة', 'Al Duhamsha UH', 'LAHJ-ALMAQA-ALDUHAMSHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النحيشة', 'Al Hunaisha HU', 'LAHJ-ALMAQA-ALHUNAISHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية المدجرة', 'Al Madjarah HU', 'LAHJ-ALMAQA-ALMADJARAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية المحلة  نجيشة', 'Al Mahlah HU', 'LAHJ-ALMAQA-ALMAHLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المليوي', 'Al Milyawi HU', 'LAHJ-ALMAQA-ALMILYAWIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النفق', 'Al Nafaq HU', 'LAHJ-ALMAQA-ALNAFAQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحمراء-اشبوط', 'AlHamra Ashboot HU', 'LAHJ-ALMAQA-ALHAMRAASH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الانبوة', 'Alanbwa HC', 'LAHJ-ALMAQA-ALANBWAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاشاهبة', 'Alashaheba HU', 'LAHJ-ALMAQA-ALASHAHEBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الدريح', 'Aldareeh HC', 'LAHJ-ALMAQA-ALDAREEHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغودرة', 'Alghawdra HU', 'LAHJ-ALMAQA-ALGHAWDRAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الحجاج', 'Alhajaj HU', 'LAHJ-ALMAQA-ALHAJAJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحصاحص', 'Alhasahes HC', 'LAHJ-ALMAQA-ALHASAHESH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجمرك', 'Aljumrk HU', 'LAHJ-ALMAQA-ALJUMRKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اليرموك(القدس)صوالحة', 'Alkadas Swaleha HU', 'LAHJ-ALMAQA-ALKADASSWA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية المعين مكابرة', 'Almae''een HU', 'LAHJ-ALMAQA-ALMAE''''EEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المصعد', 'Almasa''ad HU', 'LAHJ-ALMAQA-ALMASA''''AD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الموانسه', 'Almuanisa HU', 'LAHJ-ALMAQA-ALMUANISAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية المسيجد', 'Almusaijed HU', 'LAHJ-ALMAQA-ALMUSAIJED' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السخير', 'Alsakheer HU', 'LAHJ-ALMAQA-ALSAKHEERH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السمين', 'Alsameen HU', 'LAHJ-ALMAQA-ALSAMEENHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشعوب(الشعب)', 'Alsha''ab HC', 'LAHJ-ALMAQA-ALSHA''''ABH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصوالحة', 'Alswaleha HU', 'LAHJ-ALMAQA-ALSWALEHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي اخوان ثابت', 'Ekhwan Thabet HC', 'LAHJ-ALMAQA-EKHWANTHAB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حنو', 'Hanw HU', 'LAHJ-ALMAQA-HANWHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية حزاز', 'Hazaz HU', 'LAHJ-ALMAQA-HAZAZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حجير', 'Hujair HU', 'LAHJ-ALMAQA-HUJAIRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اقيان', 'Ikyan HU', 'LAHJ-ALMAQA-IKYANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قور', 'Koor HU', 'LAHJ-ALMAQA-KOORHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية نجد كربة', 'Najd Alkarba HU', 'LAHJ-ALMAQA-NAJDALKARB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سفال كربة', 'Sofal Karbah HU', 'LAHJ-ALMAQA-SOFALKARBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زقيحة', 'Zageehah HU', 'LAHJ-ALMAQA-ZAGEEHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMAQA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحاضنة', 'Al hadhnah HU', 'LAHJ-ALMILA-ALHADHNAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحجر', 'Alhajar HU', 'LAHJ-ALMILA-ALHAJARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القشعة', 'Alkasha''a HU', 'LAHJ-ALMILA-ALKASHA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الملاح الاعلى', 'Almalah Alaala HU', 'LAHJ-ALMILA-ALMALAHALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي الملاح', 'Almalah HC', 'LAHJ-ALMILA-ALMALAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الراحة', 'Alraha HU', 'LAHJ-ALMILA-ALRAHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرويد', 'Alrowayed HU', 'LAHJ-ALMILA-ALROWAYEDH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السرايا', 'Alsaraya HU', 'LAHJ-ALMILA-ALSARAYAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثمار (حبيل الشوارجة)', 'Athmar  (Habuil Ash Shwalejah) HU', 'LAHJ-ALMILA-ATHMAR(HAB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بلة', 'Balla HU', 'LAHJ-ALMILA-BALLAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دار الدولة', 'Dar Aldawla HU', 'LAHJ-ALMILA-DARALDAWLA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دا ر شيبان', 'Dar Shaiban HU', 'LAHJ-ALMILA-DARSHAIBAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذلبير', 'Dhalbir HU', 'LAHJ-ALMILA-DHALBIRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مهار', 'Mahar HU', 'LAHJ-ALMILA-MAHARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مويلح', 'Mowyleh HU', 'LAHJ-ALMILA-MOWYLEHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نخلين', 'Nakhlain HU', 'LAHJ-ALMILA-NAKHLAINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عقيب', 'Ukaib HU', 'LAHJ-ALMILA-UKAIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اللصات', 'allasat HU', 'LAHJ-ALMILA-ALLASATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMILA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدريجه', 'Ad Drijah HU', 'LAHJ-ALMUSA-ADDRIJAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عهامه', 'Ahama  HU', 'LAHJ-ALMUSA-AHAMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عقان', 'Akka''an HU', 'LAHJ-ALMUSA-AKKA''''ANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى المسيمير الريفي', 'Almusaimeer rural H', 'LAHJ-ALMUSA-ALMUSAIMEE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النخيله', 'Alnakhilla HU', 'LAHJ-ALMUSA-ALNAKHILLA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبيل حنش', 'Habil Hanash HU', 'LAHJ-ALMUSA-HABILHANAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جول مدرم', 'Jawlmadram HU', 'LAHJ-ALMUSA-JAWLMADRAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مخران', 'Makhran HU', 'LAHJ-ALMUSA-MAKHRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية معمرات', 'Mamarah HU', 'LAHJ-ALMUSA-MAMARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مكيديم', 'MkideM HU', 'LAHJ-ALMUSA-MKIDEMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نعمان', 'No''aman HU', 'LAHJ-ALMUSA-NO''''AMANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ريمة', 'Rayma HU', 'LAHJ-ALMUSA-RAYMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شعثاء', 'Sha''atha HU', 'LAHJ-ALMUSA-SHA''''ATHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية وادي الفقير--كدان', 'Wadi Alfakeer HU', 'LAHJ-ALMUSA-WADIALFAKE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALMUSA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدبي', 'Ad Dobi HU', 'LAHJ-ALQABB-ADDOBIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخداورة', 'Al Khadawrah HU', 'LAHJ-ALQABB-ALKHADAWRA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاغبرية', 'Alaghbarya HU', 'LAHJ-ALQABB-ALAGHBARYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الضاحي', 'Aldhahi HU', 'LAHJ-ALQABB-ALDHAHIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحنكة', 'Alhanaka HU', 'LAHJ-ALQABB-ALHANAKAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجوازعة', 'Aljawaze''a HU', 'LAHJ-ALQABB-ALJAWAZE''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكعبين', 'Alkabain HU', 'LAHJ-ALQABB-ALKABAINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القيفي', 'Alkaifi HU', 'LAHJ-ALQABB-ALKAIFIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المقطابة', 'Almeqtabbah HU', 'LAHJ-ALQABB-ALMEQTABBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المراغ', 'Almoragh HU', 'LAHJ-ALQABB-ALMORAGHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النويحة', 'Alnwaiha HU', 'LAHJ-ALQABB-ALNWAIHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الربوع', 'Alrabo''o HU', 'LAHJ-ALQABB-ALRABO''''OH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرماء', 'Alrama''a HC', 'LAHJ-ALQABB-ALRAMA''''AH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية علصان', 'Alsan HU', 'LAHJ-ALQABB-ALSANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السفيلى', 'Alsufaili HU', 'LAHJ-ALQABB-ALSUFAILIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصحبي', 'Alsuhbi HU', 'LAHJ-ALQABB-ALSUHBIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الزيق', 'Alzeek HU', 'LAHJ-ALQABB-ALZEEKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عراصم', 'Arasem HU', 'LAHJ-ALQABB-ARASEMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذر', 'Dhar HU', 'LAHJ-ALQABB-DHARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي دياش', 'Dyash HC', 'LAHJ-ALQABB-DYASHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي غويل السوق (عيريم)', 'Ghuail Alsouk (Ayreem) HC', 'LAHJ-ALQABB-GHUAILALSO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل النبي شعيب', 'Jabal Al Nabi Shoaib HU', 'LAHJ-ALQABB-JABALALNAB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي كرش', 'Karash HC', 'LAHJ-ALQABB-KARASHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي نجد ظمران', 'Najd Dhamran HC', 'LAHJ-ALQABB-NAJDDHAMRA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي سوق الخميس', 'Souk Alkhamis HC', 'LAHJ-ALQABB-SOUKALKHAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تنامر', 'Tanamer HU', 'LAHJ-ALQABB-TANAMERHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثباب', 'Thabab HU', 'LAHJ-ALQABB-THABABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ثوجان', 'Thawjan HC', 'LAHJ-ALQABB-THAWJANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية وادي ظمران', 'Wadidhamran HU', 'LAHJ-ALQABB-WADIDHAMRA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-ALQABB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العسكرية', 'Al Askariah HC', 'LAHJ-HABILJ-ALASKARIAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الردع', 'Al Rada HU', 'LAHJ-HABILJ-ALRADAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجميعي', 'Aljumaie''I HU', 'LAHJ-HABILJ-ALJUMAIE''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبيل احسن', 'Habil Ahsan HU', 'LAHJ-HABILJ-HABILAHSAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حسي الأعلى', 'Hasy Alala HU', 'LAHJ-HABILJ-HASYALALAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خيرة', 'Khairah HU', 'LAHJ-HABILJ-KHAIRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خيران', 'Khayran HU', 'LAHJ-HABILJ-KHAYRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مسك معربان', 'Mask Ma''araban HU', 'LAHJ-HABILJ-MASKMA''''AR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة - حبيل جبر', 'Maternity and childhood Center - Habil Jabr', 'LAHJ-HABILJ-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ولخ', 'Walakh HU', 'LAHJ-HABILJ-WALAKHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HABILJ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحسو', 'Al Heso HU', 'LAHJ-HALIMA-ALHESOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الدهالكه', 'Aldahakela HU', 'LAHJ-HALIMA-ALDAHAKELA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرباط', 'Alrebat HU', 'LAHJ-HALIMA-ALREBATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية أسفل الوادي', 'Asfal Alwadi HU', 'LAHJ-HALIMA-ASFALALWAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بنا', 'Bana HU', 'LAHJ-HALIMA-BANAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبيل الصريم', 'Habil Alsuraim HU', 'LAHJ-HALIMA-HABILALSUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حالمين الريفي', 'Halimeen rural H', 'LAHJ-HALIMA-HALIMEENRU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جنادة', 'Janadah HU', 'LAHJ-HALIMA-JANADAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لحكة', 'Luhaka HU', 'LAHJ-HALIMA-LUHAKAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مجحز', 'Majhaz HU', 'LAHJ-HALIMA-MAJHAZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شرعه', 'Shara''a HU', 'LAHJ-HALIMA-SHARA''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-HALIMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الظاهرة', 'Aldhahera HU', 'LAHJ-RADFAN-ALDHAHERAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله الحبيلين', 'Alhabilain Maternity & Childhood Center', 'LAHJ-RADFAN-ALHABILAIN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحاجب', 'Alhajeb HU', 'LAHJ-RADFAN-ALHAJEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجبله', 'Aljablah HU', 'LAHJ-RADFAN-ALJABLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحىة الثمرى', 'Althumair HU', 'LAHJ-RADFAN-ALTHUMAIRH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحىة السبابة', 'As Sbabah HU', 'LAHJ-RADFAN-ASSBABAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بناء', 'Bnaa HU', 'LAHJ-RADFAN-BNAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه دبسان', 'Dabsan HU', 'LAHJ-RADFAN-DABSANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحىة حىد ردفان', 'Haid Radfan HU', 'LAHJ-RADFAN-HAIDRADFAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية معربان', 'Maraban HU', 'LAHJ-RADFAN-MARABANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه مسك', 'Mesk HU', 'LAHJ-RADFAN-MESKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نمره', 'Namra HU', 'LAHJ-RADFAN-NAMRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الرحبه', 'Rahabah HU', 'LAHJ-RADFAN-RAHABAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه تونه', 'Tonah HU', 'LAHJ-RADFAN-TONAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عقيبه', 'Ukaiba HU', 'LAHJ-RADFAN-UKAIBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية وحًدة', 'Wahhada HU', 'LAHJ-RADFAN-WAHHADAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-RADFAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عبر بدر', 'Abrbadr HU', 'LAHJ-TUBAN-ABRBADRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الزيادي', 'Al-ziadi HU', 'LAHJ-TUBAN-AL-ZIADIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العند', 'Alanad HC', 'LAHJ-TUBAN-ALANADHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البيطرة', 'Albaytra HU', 'LAHJ-TUBAN-ALBAYTRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفيوش', 'Alfayosh HU', 'LAHJ-TUBAN-ALFAYOSHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحبيل', 'Alhabil HU', 'LAHJ-TUBAN-ALHABILHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحمراء', 'Alhamra''a HU', 'LAHJ-TUBAN-ALHAMRA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحاسكي', 'Alhaseki HU', 'LAHJ-TUBAN-ALHASEKIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحسيني (الخداد)', 'Alhusaini HU', 'LAHJ-TUBAN-ALHUSAINIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكدمة', 'Alkadama HU', 'LAHJ-TUBAN-ALKADAMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المجحفة', 'Almajhafa HU', 'LAHJ-TUBAN-ALMAJHAFAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المنصورة', 'Almansoura HU', 'LAHJ-TUBAN-ALMANSOURA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النوبة', 'Alnawba HU', 'LAHJ-TUBAN-ALNAWBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصرداح', 'Alserdah HU', 'LAHJ-TUBAN-ALSERDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشضيف', 'Alshadheef HU', 'LAHJ-TUBAN-ALSHADHEEF' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الشقعة', 'Alshaka''a HU', 'LAHJ-TUBAN-ALSHAKA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الوهط الريفي', 'Alwaht Rural H', 'LAHJ-TUBAN-ALWAHTRURA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بيت عياض', 'Bayt Ayadh HU', 'LAHJ-TUBAN-BAYTAYADHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بير ناصر', 'Be''ar Naser HU', 'LAHJ-TUBAN-BE''''ARNASE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دار المناصرة', 'Dar Almunasra HU', 'LAHJ-TUBAN-DARALMUNAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هران ديان', 'Haran Dayan HU', 'LAHJ-TUBAN-HARANDAYAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى إبن خلدون', 'Ibn Khaldoun Hospital', 'LAHJ-TUBAN-IBNKHALDOU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كود بيحان', 'Kood Bayhan HU', 'LAHJ-TUBAN-KOODBAYHAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الأمومة والطفوله', 'Maternity and childhood Center', 'LAHJ-TUBAN-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مقيبرة', 'Muqayberh HU', 'LAHJ-TUBAN-MUQAYBERHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الهلال الأحمر', 'Red Cresent HU', 'LAHJ-TUBAN-REDCRESENT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سفيان', 'Sofian HU', 'LAHJ-TUBAN-SOFIANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TUBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ابناء الجوازعه', 'Abna'' aljawazieih HU', 'LAHJ-TURALB-ABNA''''ALJA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العطويين', 'Al Attwain HU', 'LAHJ-TURALB-ALATTWAINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفرشه', 'Alfarsh HC', 'LAHJ-TURALB-ALFARSHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الغول', 'Alghul HC', 'LAHJ-TURALB-ALGHULHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القاضي', 'Alkhadhi HU', 'LAHJ-TURALB-ALKHADHIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخطابية', 'Alkhatabya HU', 'LAHJ-TURALB-ALKHATABYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعامية', 'Alma''amya HU', 'LAHJ-TURALB-ALMA''''AMYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المكحلية', 'Almakhooleah HU', 'LAHJ-TURALB-ALMAKHOOLE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيةالمشاريج', 'Almashareej HU', 'LAHJ-TURALB-ALMASHAREE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرجاع', 'Alraja''a HU', 'LAHJ-TURALB-ALRAJA''''AH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الريده', 'Alryda HU', 'LAHJ-TURALB-ALRYDAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشعبة', 'Alshaba HU', 'LAHJ-TURALB-ALSHABAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشعب الاعلى (شعب الأوسط)', 'Alsheab Alaala (Sha''ab al awst) HU', 'LAHJ-TURALB-ALSHEABALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عراعره', 'Araera HU', 'LAHJ-TURALB-ARAERAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصميته', 'As Samitah HU', 'LAHJ-TURALB-ASSAMITAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حيح', 'Hayih HU', 'LAHJ-TURALB-HAYIHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة', 'Maternity and childhood Center', 'LAHJ-TURALB-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شعب الاسفل', 'Sha''ab al asfl  HU', 'LAHJ-TURALB-SHA''''ABALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شوار', 'Shwar HU', 'LAHJ-TURALB-SHWARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذنوبه', 'Thanobah HU', 'LAHJ-TURALB-THANOBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-TURALB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية أعلى حطيب', 'A''ala Hateeb HU', 'LAHJ-YAFA''''A-A''''ALAHATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحريري', 'Al Hariri HU', 'LAHJ-YAFA''''A-ALHARIRIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القعيطي', 'Alkuaiti HU', 'LAHJ-YAFA''''A-ALKUAITIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المحجبة', 'Almuhajaba HU', 'LAHJ-YAFA''''A-ALMUHAJABA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى السلام الريفي', 'Alsalam rural H', 'LAHJ-YAFA''''A-ALSALAMRUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية اليزيدي', 'Alyazeedi HU', 'LAHJ-YAFA''''A-ALYAZEEDIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بين المحاور', 'Bain Almahawer HU', 'LAHJ-YAFA''''A-BAINALMAHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ذي ناخب', 'Dhi Nakhib HC', 'LAHJ-YAFA''''A-DHINAKHIBH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حطيب', 'Hateeb HU', 'LAHJ-YAFA''''A-HATEEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كبد', 'Kabad HU', 'LAHJ-YAFA''''A-KABADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لحنوش', 'Lahnoush HU', 'LAHJ-YAFA''''A-LAHNOUSHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مرفد', 'Marfad HU', 'LAHJ-YAFA''''A-MARFADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحه الانجابيه اكتوبر', 'October Reproductive Health Center', 'LAHJ-YAFA''''A-OCTOBERREP' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تلب', 'Talab HU', 'LAHJ-YAFA''''A-TALABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAFA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية أعرام الرباط', 'A''aram Alrebat HU', 'LAHJ-YAHR-A''''ARAMALR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عدن الحواشب', 'Aden Al Hawasheb HU', 'LAHJ-YAHR-ADENALHAWA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي السلام ضول', 'Alsalam Dhul HC', 'LAHJ-YAHR-ALSALAMDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السلام', 'Alsalam HU', 'LAHJ-YAHR-ALSALAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية معربان', 'Ma''araban HU', 'LAHJ-YAHR-MA''''ARABAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة يهر', 'Maternity and Childhood Center Yahr', 'LAHJ-YAHR-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تيقراء', 'Takraa HU', 'LAHJ-YAHR-TAKRAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'LAHJ-YAHR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة صحية الجفرة (مؤقت)', '(Temporary) Al Jafra HU', 'MARIB-HARIB-(TEMPORARY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه القحاش', 'Aal Qahash HU', 'MARIB-HARIB-AALQAHASHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحيه الحد', 'Al Had HU', 'MARIB-HARIB-ALHADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الهوش', 'Al Hawsh HU', 'MARIB-HARIB-ALHAWSHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الصداره', 'Al Sadarah HU', 'MARIB-HARIB-ALSADARAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حريب العام', 'Harib General Hospital', 'MARIB-HARIB-HARIBGENER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحيه جراذاء', 'Jaratha''a HU', 'MARIB-HARIB-JARATHA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شرق', 'Sharq HU', 'MARIB-HARIB-SHARQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الذراع ال زيد', 'Theraa Aal Zayed HU', 'MARIB-HARIB-THERAAAALZ' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'العطير', 'العطير', 'MARIB-HARIB-العطير' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-HARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الست الصحية الوحدة', 'AL Sat HU', 'MARIB-MARIB-ALSATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفضي', 'Aal Fedhi HC', 'MARIB-MARIB-AALFEDHIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العواش', 'Al Awash HC', 'MARIB-MARIB-ALAWASHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحاني', 'Al Hani HU', 'MARIB-MARIB-ALHANIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستتفى الحزمة الريفي', 'Al Hazmah Rural H', 'MARIB-MARIB-ALHAZMAHRU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الحصون (الوحدة)', 'Al Hosoon( al Wahdah ) Hospital', 'MARIB-MARIB-ALHOSOON(A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكولة', 'Al Kulah HU', 'MARIB-MARIB-ALKULAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المرداء', 'Al Marda''a HU', 'MARIB-MARIB-ALMARDA''''A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة صحية  المصطفى', 'Al Mustafa HU', 'MARIB-MARIB-ALMUSTAFAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي النقيعاء', 'Al Ngaah HC', 'MARIB-MARIB-ALNGAAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الساقط', 'Al Saqet HU', 'MARIB-MARIB-ALSAQETHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشهيد محمد الدرة', 'Al Shaheed Mohamed Al Durrah H', 'MARIB-MARIB-ALSHAHEEDM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الطحيل', 'Al Taheel HC', 'MARIB-MARIB-ALTAHEELHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه التراحم', 'Al Trahom HU', 'MARIB-MARIB-ALTRAHOMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي المشير', 'Al masheeق Erq Aal Shabwan HC', 'MARIB-MARIB-ALMASHEEقE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العرقه', 'Alarqah HU', 'MARIB-MARIB-ALARQAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرمسة', 'Alramsah HC', 'MARIB-MARIB-ALRAMSAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الحدباء ال عوشان', 'Hadba''a Aal Awshan HU', 'MARIB-MARIB-HADBA''''AAA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جو النسيم', 'Jaw Al Naseem HU', 'MARIB-MARIB-JAWALNASEE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى كرى العام', 'Karaa Hospital', 'MARIB-MARIB-KARAAHOSPI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية قشع البرد', 'Qsh Albrad HU', 'MARIB-MARIB-QSHALBRADH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي سلوى', 'Salwah HC', 'MARIB-MARIB-SALWAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'السميا', 'السميا', 'MARIB-MARIB-السميا' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, '22 مايو', '22 مايو', 'MARIB-MARIBC-22مايو' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشهيد احمد جحزه (مؤقت )', 'Ahmed Ghazah H (Temp)', 'MARIB-MARIBC-AHMEDGHAZA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجفينة', 'Al Goviena HU', 'MARIB-MARIBC-ALGOVIENAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجفينة قطاع 10', 'Al Govina HU', 'MARIB-MARIBC-ALGOVINAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الجفينة الميداني (26 سبتمبر) مؤقت', 'Al Govina Hospital (Temporary)', 'MARIB-MARIBC-ALGOVINAHO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخسيف', 'Al Khaseef HU', 'MARIB-MARIBC-ALKHASEEFH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المطار', 'Al Matar HU', 'MARIB-MARIBC-ALMATARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرجو', 'Al Rajw HC', 'MARIB-MARIBC-ALRAJWHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشهيد محمد هائل للامومة و الطفولة', 'Al Shaheed Mohamed Ha''il H', 'MARIB-MARIBC-ALSHAHEEDM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز صحي السلطان', 'Al Sultan HU', 'MARIB-MARIBC-ALSULTANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستوصف المجد', 'Almajd HC', 'MARIB-MARIBC-ALMAJD HC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الميداني السويداء', 'Alsuwayda Almaydani Hospital', 'MARIB-MARIBC-ALSUWAYDAA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الروضة', 'Ar Rawdah HU', 'MARIB-MARIBC-ARRAWDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كلية المجتمع', 'Community Collage HU', 'MARIB-MARIBC-COMMUNITYC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الطوارئ', 'Emergency Hospital', 'MARIB-MARIBC-EMERGENCYH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز صحي فاطمة (ال مثنى )', 'Fatema (Al Muthanaa)', 'MARIB-MARIBC-FATEMA(ALM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية منين الحدد', 'Maneen Al Hadad HU', 'MARIB-MARIBC-MANEENALHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفي مارب العسكري', 'Marib Military Hospital', 'MARIB-MARIBC-MARIBMILIT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MARIBC' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قرود', 'Qerood HU', 'MARIB-MEDGHA-QEROODHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-MEDGHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى رغوان الريفى', 'Raghwan Hospital', 'MARIB-RAGHWA-RAGHWANHOS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'MARIB-RAGHWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العبر', 'Alabr HC', 'SAYUN-ALABR-ALABRHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALABR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالوديعة', 'Manfadh Alwade''a HU', 'SAYUN-ALABR-MANFADHALW' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALABR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حوارم', 'Hawarem HC', 'SAYUN-ALQAF-HAWAREMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQAF' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عقران', 'Akran HU', 'SAYUN-ALQATN-AKRANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الحياه العام', 'Al Hayah General H', 'SAYUN-ALQATN-ALHAYAHGEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرملة', 'Al Ramlah HU', 'SAYUN-ALQATN-ALRAMLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الساحة', 'Al Saha HU', 'SAYUN-ALQATN-ALSAHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه العدان', 'Aladan HU', 'SAYUN-ALQATN-ALADANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العجلانيه', 'Alajlania HU', 'SAYUN-ALQATN-ALAJLANIAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي النموذجي العقاد', 'Alakkad HC', 'SAYUN-ALQATN-ALAKKADHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العنين', 'Alaneen HC', 'SAYUN-ALQATN-ALANEENHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الباطنه', 'Albatena HU', 'SAYUN-ALQATN-ALBATENAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الجوادة', 'Aljawda HC', 'SAYUN-ALQATN-ALJAWDAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الريان', 'Alrayan HU', 'SAYUN-ALQATN-ALRAYANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بن ناصر', 'Bani Naser HU', 'SAYUN-ALQATN-BANINASERH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دار الراك', 'Daar Al Raak HU', 'SAYUN-ALQATN-DAARALRAAK' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية غصيص', 'Gusis HU', 'SAYUN-ALQATN-GUSISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حذية', 'Hadhya HU', 'SAYUN-ALQATN-HADHYAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي هينين', 'Hainan HC', 'SAYUN-ALQATN-HAINANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حويلة', 'Hwaila HU', 'SAYUN-ALQATN-HWAILAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خشامر', 'Khshamer HU', 'SAYUN-ALQATN-KHSHAMERHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي منوب', 'Manoub HC', 'SAYUN-ALQATN-MANOUBHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة القطن', 'Maternity and Chilhood Al Qatn HC', 'SAYUN-ALQATN-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ALQATN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخربه', 'Alkherba HU', 'SAYUN-AMD-ALKHERBAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرحب', 'Alrehb HU', 'SAYUN-AMD-ALREHBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستوصف الشعبة التعاوني', 'Alshuebat Altaawoi HU', 'SAYUN-AMD-ALSHUEBATA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عمد', 'Amd HC', 'SAYUN-AMD-AMDHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحالة (حالة باصليب)', 'Halat baslib HU', 'SAYUN-AMD-HALATBASLI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه خنفر', 'Khanfar HU', 'SAYUN-AMD-KHANFARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية طمحان', 'Tamhan HU', 'SAYUN-AMD-TAMHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عنق', 'ank HU', 'SAYUN-AMD-ANKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرباط (رباط باكوبن)', 'rebat Bakoban HU', 'SAYUN-AMD-REBATBAKOB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-AMD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالمخيبية', 'Almukhaibiah HU', 'SAYUN-ASSAWM-ALMUKHAIBI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بالسوم', 'Alsawm HC', 'SAYUN-ASSAWM-ALSAWMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عصم', 'Asm HU', 'SAYUN-ASSAWM-ASMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية باصفية', 'BasafiahHU', 'SAYUN-ASSAWM-BASAFIAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة الصحية ضبعات', 'Dhaba''at HU', 'SAYUN-ASSAWM-DHABA''''ATH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية فغمة', 'Fakma HU', 'SAYUN-ASSAWM-FAKMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي سناء', 'Sana HC', 'SAYUN-ASSAWM-SANAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ASSAWM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حجرالصيعر', 'Hajralsaia''ar HC', 'SAYUN-HAGRAS-HAJRALSAIA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HAGRAS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه قني', 'Kinaa HU', 'SAYUN-HAGRAS-KINAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HAGRAS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية علط', 'Alat HU', 'SAYUN-HURAID-ALATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عندل', 'Andal HU', 'SAYUN-HURAID-ANDALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى مديرية حريضه', 'Huraidha rural H', 'SAYUN-HURAID-HURAIDHARU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي قرن بن عدوان', 'Karn Bn Adwan HC', 'SAYUN-HURAID-KARNBNADWA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نفحون', 'Nafhoon HU', 'SAYUN-HURAID-NAFHOONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زاهر باقيس', 'Zahir Ba Qais HU', 'SAYUN-HURAID-ZAHIRBAQAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-HURAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه القرن', 'Alkarn Hu', 'SAYUN-RAKHYA-ALKARNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المخارم', 'Almakharem HU', 'SAYUN-RAKHYA-ALMAKHAREM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امباع', 'Amba''a HU', 'SAYUN-RAKHYA-AMBA''''AHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قرنطوع', 'Karnato''o HU', 'SAYUN-RAKHYA-KARNATO''''O' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سهوة', 'Sahwa HU', 'SAYUN-RAKHYA-SAHWAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي صناء', 'sana HC', 'SAYUN-RAKHYA-SANAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RAKHYA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عيوة', 'Away HU', 'SAYUN-RUMAH-AWAYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RUMAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى رماه الريفي', 'Ramah rural H', 'SAYUN-RUMAH-RAMAHRURAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RUMAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رأس النطح', 'Ras An Natah HU', 'SAYUN-RUMAH-RASANNATAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RUMAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثوف', 'Thouf HU', 'SAYUN-RUMAH-THOUFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-RUMAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البلاد', 'Al Bilad HU', 'SAYUN-SAH-ALBILADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الضبيعة', 'Aldhabbaia''a HU', 'SAYUN-SAH-ALDHABBAIA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحسك', 'Alhasak HU', 'SAYUN-SAH-ALHASAKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي الكتنة', 'Alkatana HC', 'SAYUN-SAH-ALKATANAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخامرة', 'Alkhamera HU', 'SAYUN-SAH-ALKHAMERAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ضمرالنهر', 'Dhamaralnaher HU', 'SAYUN-SAH-DHAMARALNA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي غيل عمر', 'Ghail Omar Alardh HU', 'SAYUN-SAH-GHAILOMARA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الأمومة والطفولة بالمركز الصحي ساه', 'Maternity and Chilhood HC in Sah', 'SAYUN-SAH-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي رسب', 'Rasab HC', 'SAYUN-SAH-RASABHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية راوك', 'Rawk HU', 'SAYUN-SAH-RAWKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صيقة', 'Saika HU', 'SAYUN-SAH-SAIKAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سكدان', 'Sakadan HU', 'SAYUN-SAH-SAKADANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية طاران', 'Taran HU', 'SAYUN-SAH-TARANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 22 مايو', '22 May HU', 'SAYUN-SAYUN-22MAYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الهدى الطبي', 'Al Huda Medical Center', 'SAYUN-SAYUN-ALHUDAMEDI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العرض', 'Alardh HC', 'SAYUN-SAYUN-ALARDHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العرض', 'Alardh HU', 'SAYUN-SAYUN-ALARDHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الغرفة', 'Alghurfa HC', 'SAYUN-SAYUN-ALGHURFAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حي الحوطة', 'Alhawta HU', 'SAYUN-SAYUN-ALHAWTAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القرن', 'Alkarn HC', 'SAYUN-SAYUN-ALKARNHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخيام', 'Alkhiam HU', 'SAYUN-SAYUN-ALKHIAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بور', 'Bor  HC', 'SAYUN-SAYUN-BORHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بور البلاد', 'Bor Al Balad HU', 'SAYUN-SAYUN-BORALBALAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مدودة', 'Madwda HC', 'SAYUN-SAYUN-MADWDAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مريمه', 'Mariama HU', 'SAYUN-SAYUN-MARIAMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الأمومة والطفولة (حي الوحدة)', 'Maternity and Childhood Center  (Hai AlWahda)', 'SAYUN-SAYUN-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الطوارئ التوليدية', 'Obstetric Emergency Hospital', 'SAYUN-SAYUN-OBSTETRICE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سحيل سيؤن', 'Sahil Sayo''on HU', 'SAYUN-SAYUN-SAHILSAYO''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى سيؤن العام', 'Sayo''on Public Hospital', 'SAYUN-SAYUN-SAYO''''ONPU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شعب الحصان', 'Shaeb Al hisan HU', 'SAYUN-SAYUN-SHAEBALHIS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شحوح', 'Shahuh HU', 'SAYUN-SAYUN-SHAHUHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شرمه', 'Sharma HU', 'SAYUN-SAYUN-SHARMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سحيل بور', 'Suhail Bor HU', 'SAYUN-SAYUN-SUHAILBORH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تاربة السحيل القبلي', 'Suhail Kabali tarepa HU', 'SAYUN-SAYUN-SUHAILKABA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصليلة', 'Sulailah HU', 'SAYUN-SAYUN-SULAILAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي تريس', 'Tarais HC', 'SAYUN-SAYUN-TARAISHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي تاربة', 'Tareba HC', 'SAYUN-SAYUN-TAREBAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تاربة البلاد', 'Tareba albelad HU', 'SAYUN-SAYUN-TAREBAALBE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تاربة وادي بن سلمان', 'Wadi Bin Salman HU', 'SAYUN-SAYUN-WADIBINSAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حوطة سلطانه', 'hawatat Sultana HU', 'SAYUN-SAYUN-HAWATATSUL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SAYUN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحاوي', 'Al Hawi HU', 'SAYUN-SHIBAM-ALHAWIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحوطه', 'Alhawta HC', 'SAYUN-SHIBAM-ALHAWTAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القاره', 'Alkara HU', 'SAYUN-SHIBAM-ALKARAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المحجر', 'Almhagar HU', 'SAYUN-SHIBAM-ALMHAGARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بحيره', 'Buhaira HU', 'SAYUN-SHIBAM-BUHAIRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جفل', 'Jafl HU', 'SAYUN-SHIBAM-JAFLHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جوجة', 'Joja HU', 'SAYUN-SHIBAM-JOJAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جعيمه', 'Juaima HU', 'SAYUN-SHIBAM-JUAIMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قريو', 'Karyo HU', 'SAYUN-SHIBAM-KARYOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خمور', 'Khamor HU', 'SAYUN-SHIBAM-KHAMORHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله شبام', 'Maternity and Childhood Center Shibam', 'SAYUN-SHIBAM-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية موشح', 'Mawshah HU', 'SAYUN-SHIBAM-MAWSHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بوادي بن علي', 'Wadi Bani Ali HC', 'SAYUN-SHIBAM-WADIBANIAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-SHIBAM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفجير', 'Al Fojerr HU', 'SAYUN-TARIM-ALFOJERRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القرية', 'Al Qarya HC', 'SAYUN-TARIM-ALQARYAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الروضة', 'Al Rawdah HU', 'SAYUN-TARIM-ALRAWDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركزاليرموك الصحي', 'Al Yarmouk HC', 'SAYUN-TARIM-ALYARMOUKH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الميداني', 'Al maydani H', 'SAYUN-TARIM-ALMAYDANIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغرف', 'Alghurf HU', 'SAYUN-TARIM-ALGHURFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية القوز', 'Alkawz  HU', 'SAYUN-TARIM-ALKAWZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الخون', 'Alkhawn HU', 'SAYUN-TARIM-ALKHAWNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الردود الصحي', 'Alradod HC', 'SAYUN-TARIM-ALRADODHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بالرحبة', 'Alrahaba HU', 'SAYUN-TARIM-ALRAHABAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بالسويري', 'Alswairi HC', 'SAYUN-TARIM-ALSWAIRIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الواسطة', 'Alwaseta HU', 'SAYUN-TARIM-ALWASETAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عينات', 'Aynat HU', 'SAYUN-TARIM-AYNATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بباعلال', 'Balal HU', 'SAYUN-TARIM-BALALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دمون', 'Damon HU', 'SAYUN-TARIM-DAMONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حكمة', 'Hakama HU', 'SAYUN-TARIM-HAKAMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حصاة المقاتيل', 'Hasat Almaqateel HU', 'SAYUN-TARIM-HASATALMAQ' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قسم', 'Kasam HU', 'SAYUN-TARIM-KASAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مشطه', 'Mashtah HC', 'SAYUN-TARIM-MASHTAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة تريم', 'Maternity and Chilhood Tarim HC', 'SAYUN-TARIM-MATERNITYA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مولى عيديد', 'Mawla Eideed HU', 'SAYUN-TARIM-MAWLAEIDEE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شريوف', 'Sharuf HU', 'SAYUN-TARIM-SHARUFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى تريم الطوارئ التوليدية', 'Tarim Obstetric Emergency H', 'SAYUN-TARIM-TARIMOBSTE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ثبي', 'Thebe HC', 'SAYUN-TARIM-THEBEHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-TARIM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القيعان', 'Al Qian HU', 'SAYUN-THAMUD-ALQIANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-THAMUD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى ثمود الريفي', 'Thamoud H', 'SAYUN-THAMUD-THAMOUDH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-THAMUD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية عدب', 'Adab HU', 'SAYUN-WADIAL-ADABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البويرقات', 'Al Boiregat HU', 'SAYUN-WADIAL-ALBOIREGAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية الهشم', 'Al Hesham HU', 'SAYUN-WADIAL-ALHESHAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصيقة', 'AlSaiga HU', 'SAYUN-WADIAL-ALSAIGAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية العقوبية', 'Alagoubya HU', 'SAYUN-WADIAL-ALAGOUBYAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية الخشعة', 'Alkhasha''ah', 'SAYUN-WADIAL-ALKHASHA''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي فضح', 'Fadhah HC', 'SAYUN-WADIAL-FADHAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حوره', 'Hawra H', 'SAYUN-WADIAL-HAWRAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز صحي قعوضة', 'Kaowdha HC', 'SAYUN-WADIAL-KAOWDHAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شرج الشريف', 'sharg Alshrief  HU', 'SAYUN-WADIAL-SHARGALSHR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-WADIAL' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي منوخ', 'Manwakh HC', 'SAYUN-ZAMAKH-MANWAKHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SAYUN-ZAMAKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى عين', 'Ain H', 'SHABWA-AIN-AINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده لصحية العطفة', 'Al Adfah HU', 'SHABWA-AIN-ALADFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية العكارم', 'Al Akarim HU', 'SHABWA-AIN-ALAKARIMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الدرب ال الفلاحين', 'Darb Al FALAHEEN HU', 'SHABWA-AIN-DARBALFALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية درب العمال', 'Darb Al Omal HU', 'SHABWA-AIN-DARBALOMAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية جعدر', 'Jaadar Aal Aqeel HU', 'SHABWA-AIN-JAADARAALA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه مبلقه', 'Mablakah HU', 'SHABWA-AIN-MABLAKAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية منوى', 'Manwa HU', 'SHABWA-AIN-MANWAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية موسطة', 'Mawsatat Al Ain HU', 'SHABWA-AIN-MAWSATATAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية شماطيط', 'Shmateet HU', 'SHABWA-AIN-SHMATEETHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-AIN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخظراء', 'Al Khadhra''a   HU', 'SHABWA-ALTALH-ALKHADHRA''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشرج', 'Al Sharj HU', 'SHABWA-ALTALH-ALSHARJHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الطلح', 'Al alh  HC', 'SHABWA-ALTALH-ALALHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية ضدة', 'Dhedah H U', 'SHABWA-ALTALH-DHEDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحبة كلوة', 'Kalooh  HU', 'SHABWA-ALTALH-KALOOHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كراثة', 'Karathah  HU', 'SHABWA-ALTALH-KARATHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه معبر', 'Maabar H U', 'SHABWA-ALTALH-MAABARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدء الصحية  الريده', 'Raydah Ba Saeed  HU', 'SHABWA-ALTALH-RAYDAHBASA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تمون', 'Tamoon H U', 'SHABWA-ALTALH-TAMOONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ALTALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغييلة', 'AL Gheelah HU', 'SHABWA-ARRAWD-ALGHEELAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العطفة', 'Al Atfah HU', 'SHABWA-ARRAWD-ALATFAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية الحيرة', 'Al Hairah HU', 'SHABWA-ARRAWD-ALHAIRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية حنكة سلمون', 'Al Hankah Salmoon HU', 'SHABWA-ARRAWD-ALHANKAHSA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القرن', 'Al Qarn HU', 'SHABWA-ARRAWD-ALQARNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الشعيب', 'Al Shaeeb HU', 'SHABWA-ARRAWD-ALSHAEEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية الشروج', 'Al Sherooj HU', 'SHABWA-ARRAWD-ALSHEROOJH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الروضة', 'Ar Rawdah Hospital', 'SHABWA-ARRAWD-ARRAWDAHHO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحي الغيل', 'Ghareer Al Ghail HC', 'SHABWA-ARRAWD-GHAREERALG' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل نعمان', 'Jabal Noman HU', 'SHABWA-ARRAWD-JABALNOMAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية لماطر', 'Lamater HU', 'SHABWA-ARRAWD-LAMATERHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة', 'Maternity & Childhood Center', 'SHABWA-ARRAWD-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نخل', 'Nakhl HU', 'SHABWA-ARRAWD-NAKHLHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الصحي عمقين', 'Omqain HC', 'SHABWA-ARRAWD-OMQAINHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة ريمة الصحية', 'Raimah HU', 'SHABWA-ARRAWD-RAIMAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحة الصحية الشعبين', 'Shabain Salmoon HU', 'SHABWA-ARRAWD-SHABAINSAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARRAWD' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه العطف', 'AL Atf H.U', 'SHABWA-ARMA-ALATFH.U' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحره', 'Al Hurrah H U', 'SHABWA-ARMA-ALHURRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الثجه', 'Al Theja H U', 'SHABWA-ARMA-ALTHEJAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى عرماء', 'Arma H', 'SHABWA-ARMA-ARMAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه سمره', 'Samrah H U', 'SHABWA-ARMA-SAMRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه شبوه القديمه', 'Shabwah Al Qadeema H U', 'SHABWA-ARMA-SHABWAHALQ' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه باكيله', 'bakela H.U', 'SHABWA-ARMA-BAKELAH.U' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه منقله', 'mankalah HU', 'SHABWA-ARMA-MANKALAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ARMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى المسحاء الصعيد الريفي', 'Al Mas''ha Al Saeed Hospital', 'SHABWA-ASSAID-ALMAS''''HAA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى المصينعة', 'Al Musaina''ah Hospital', 'SHABWA-ASSAID-ALMUSAINA''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الريد', 'Al Raeed HU', 'SHABWA-ASSAID-ALRAEEDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه السفال', 'Al Sefal HU', 'SHABWA-ASSAID-ALSEFALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه السر', 'Al Ser HU', 'SHABWA-ASSAID-ALSERHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الشعبه', 'Al Shuebah HU', 'SHABWA-ASSAID-ALSHUEBAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفولة الصعيد', 'As Said Maternity & Childhood Center', 'SHABWA-ASSAID-ASSAIDMATE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه خمار', 'Khimar HU', 'SHABWA-ASSAID-KHIMARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مقبلة', 'Maqbelah HC', 'SHABWA-ASSAID-MAQBELAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه مربون', 'Marboon HU', 'SHABWA-ASSAID-MARBOONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سرع', 'Seraa HU', 'SHABWA-ASSAID-SERAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي يشبم', 'Yashbem HC', 'SHABWA-ASSAID-YASHBEMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ASSAID' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجابية', 'Al Jabyah HU', 'SHABWA-ATAQ-ALJABYAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المحضرة', 'Al Mahdharah HU', 'SHABWA-ATAQ-ALMAHDHARA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشبيكة', 'Al Shabeekah HU', 'SHABWA-ATAQ-ALSHABEEKA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المذنب', 'Al modnib HU', 'SHABWA-ATAQ-ALMODNIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصحيفة', 'Al sahifa HU', 'SHABWA-ATAQ-ALSAHIFAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجشم', 'Aljashm HU', 'SHABWA-ATAQ-ALJASHMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكرموم', 'Alqarmom HU', 'SHABWA-ATAQ-ALQARMOMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النصيرة', 'An Naserh HU', 'SHABWA-ATAQ-ANNASERHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الرباط الصحي', 'Ar Rbat HC', 'SHABWA-ATAQ-ARRBATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عتق', 'Ataq HC', 'SHABWA-ATAQ-ATAQHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية با كبيرة', 'Ba Kabeerah HU', 'SHABWA-ATAQ-BAKABEERAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جول العاض', 'Jawl Al ADHI HU', 'SHABWA-ATAQ-JAWLALADHI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قرى خليفة', 'Khalifa villages HU', 'SHABWA-ATAQ-KHALIFAVIL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية خمر', 'Khamir HU', 'SHABWA-ATAQ-KHAMIRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مري', 'Mari HU', 'SHABWA-ATAQ-MARIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ماس', 'Mas HU', 'SHABWA-ATAQ-MASHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نوخان', 'Nawkhan HU', 'SHABWA-ATAQ-NAWKHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قوبان', 'Qawban HU', 'SHABWA-ATAQ-QAWBANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الهلال الاحمر', 'Red Crescent Center', 'SHABWA-ATAQ-REDCRESCEN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صدر باراس', 'Seder Baras HU', 'SHABWA-ATAQ-SEDERBARAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-ATAQ' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الكراع (وادي النحر)', 'Al Kerae''e HC  (Wadi Al Nahr)', 'SHABWA-BAYHAN-ALKERAE''''E' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه خدراء', 'Al Khadra''a HU', 'SHABWA-BAYHAN-ALKHADRA''''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحرجه', 'Al harajh HU', 'SHABWA-BAYHAN-ALHARAJHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ذمر', 'Dhamr HC', 'SHABWA-BAYHAN-DHAMRHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه غنيه', 'Ghanneyah HU', 'SHABWA-BAYHAN-GHANNEYAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه جرادان', 'Jardan HU', 'SHABWA-BAYHAN-JARDANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة بيحان', 'Maternity & Childhood HC', 'SHABWA-BAYHAN-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي موقس', 'Mawqes  HC', 'SHABWA-BAYHAN-MAWQESHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه قرين', 'Qareen HU', 'SHABWA-BAYHAN-QAREENHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-BAYHAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الخر', 'Al Khar Health Unit HU', 'SHABWA-DHAR-ALKHARHEAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الراحب', 'Al Raheb HU', 'SHABWA-DHAR-ALRAHEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدةالصحية بامسله', 'Bamslah HU', 'SHABWA-DHAR-BAMSLAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي دهر', 'Douhr Health Center HC', 'SHABWA-DHAR-DOUHRHEALT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدةالصحيةخرطة', 'Khartah Health Unit HU', 'SHABWA-DHAR-KHARTAHHEA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه مطره', 'MTRA HU', 'SHABWA-DHAR-MTRAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نوعة', 'Naw''ah HU', 'SHABWA-DHAR-NAW''''AHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-DHAR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخبر', 'Al Khabar HU', 'SHABWA-HABBAN-ALKHABARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشريره', 'Al Shareerah HU', 'SHABWA-HABBAN-ALSHAREERA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبان', 'Habban HU', 'SHABWA-HABBAN-HABBANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى حبان', 'Habban Hospital', 'SHABWA-HABBAN-HABBANHOSP' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي هدى', 'Huda HC', 'SHABWA-HABBAN-HUDAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي لهيه', 'Lahiah HC', 'SHABWA-HABBAN-LAHIAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HABBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المدينة', 'Al Madeena HU', 'SHABWA-HATIB-ALMADEENAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HATIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرباط', 'Umm Rebat HU', 'SHABWA-HATIB-UMMREBATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-HATIB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المذنب', 'AL Muthneb HU', 'SHABWA-JARDAN-ALMUTHNEBH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الظاهرة', 'Al Dhaherah Health Unit', 'SHABWA-JARDAN-ALDHAHERAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المثنأه', 'Al Mthnah HU', 'SHABWA-JARDAN-ALMTHNAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عياذ', 'Ayath HC', 'SHABWA-JARDAN-AYATHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جول بن حيدر', 'Jawl Bin Haidar HU', 'SHABWA-JARDAN-JAWLBINHAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله جردان', 'Jirdan Mother and Child Health Center', 'SHABWA-JARDAN-JIRDANMOTH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصعيد', 'Saeed Jardan HU', 'SHABWA-JARDAN-SAEEDJARDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية يثوف', 'Yethof HU', 'SHABWA-JARDAN-YETHOFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-JARDAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي العاقر', 'Al Aaqer HC', 'SHABWA-MERKHA-ALAAQERHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الفرشة', 'Al Farshah HU', 'SHABWA-MERKHA-ALFARSHAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحيدة', 'Al Haidah HU', 'SHABWA-MERKHA-ALHAIDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجفرة', 'Al Jafrah HU', 'SHABWA-MERKHA-ALJAFRAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القرن', 'Al Karn HU', 'SHABWA-MERKHA-ALKARNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخيس', 'Al Khais HU', 'SHABWA-MERKHA-ALKHAISHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعفاري', 'Al Magfari HU', 'SHABWA-MERKHA-ALMAGFARIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية هجر ال عوض', 'Hajr Aal Awad HU', 'SHABWA-MERKHA-HAJRAALAWA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 22 مايو', '22 May HU', 'SHABWA-MERKHA-22MAYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الديمه', 'Al Daimah HU', 'SHABWA-MERKHA-ALDAIMAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الهجير', 'Al Hajeer HC', 'SHABWA-MERKHA-ALHAJEERHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  الهجر', 'Al Hajr HU', 'SHABWA-MERKHA-ALHAJRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجبنون', 'Algabnon UH', 'SHABWA-MERKHA-ALGABNONUH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجرشة', 'Algrsha UH', 'SHABWA-MERKHA-ALGRSHAUH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الحزم', 'Alhazem HU', 'SHABWA-MERKHA-ALHAZEMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المتنه', 'Almthena HU', 'SHABWA-MERKHA-ALMTHENAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الوشيجه', 'Alwashigah HU', 'SHABWA-MERKHA-ALWASHIGAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ظليمين', 'Dhulaymain HC', 'SHABWA-MERKHA-DHULAYMAIN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي خورة', 'Khawrah HC', 'SHABWA-MERKHA-KHAWRAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المسند', 'Masnad HU', 'SHABWA-MERKHA-MASNADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية رمه', 'Rammah HU', 'SHABWA-MERKHA-RAMMAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ثعيلبان', 'Thaelban HU', 'SHABWA-MERKHA-THAELBANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذات الجار', 'That Al Jar HU', 'SHABWA-MERKHA-THATALJARH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى واسط', 'Waset Hospital', 'SHABWA-MERKHA-WASETHOSPI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة صحية زهوان', 'Zahwan HU', 'SHABWA-MERKHA-ZAHWANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-MERKHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العوشة', 'Al Awshah HU', 'SHABWA-NISAB-ALAWSHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الحنك', 'Al Hanak HC', 'SHABWA-NISAB-ALHANAKHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجفر', 'Al Jafr HU', 'SHABWA-NISAB-ALJAFRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النقوب', 'Al Nuqoob HU', 'SHABWA-NISAB-ALNUQOOBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصلبة', 'Al Salbah HU', 'SHABWA-NISAB-ALSALBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الكورة', 'Alkorah HU', 'SHABWA-NISAB-ALKORAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية امكداه', 'Amkadah HU', 'SHABWA-NISAB-AMKADAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية بئر النخل', 'Beer Al Nakhl HU', 'SHABWA-NISAB-BEERALNAKH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امشرفاء', 'Emsharfaa HU', 'SHABWA-NISAB-EMSHARFAAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امصلب', 'Emslbah HU', 'SHABWA-NISAB-EMSLBAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية امزباعية', 'Emzebaaiah HU', 'SHABWA-NISAB-EMZEBAAIAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جباه', 'Jubah HC', 'SHABWA-NISAB-JUBAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية معجب', 'Majab HU', 'SHABWA-NISAB-MAJABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية معربه', 'Marabah HU', 'SHABWA-NISAB-MARABAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفولة نصاب', 'Nisab Maternity & Childhood Center', 'SHABWA-NISAB-NISABMATER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي رباط', 'Rebat HC', 'SHABWA-NISAB-REBATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية سقام', 'Seqam HU', 'SHABWA-NISAB-SEQAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية صلدة', 'Slaldah HU', 'SHABWA-NISAB-SLALDAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-NISAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عين بامعبد', 'Ain Ba Maeebad HU', 'SHABWA-RUDUM-AINBAMAEEB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحامية', 'Al Hameyah HU', 'SHABWA-RUDUM-ALHAMEYAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه باصفاق', 'Ba safaq HU', 'SHABWA-RUDUM-BASAFAQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بئر علي', 'Beer Ali HC', 'SHABWA-RUDUM-BEERALIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عرقة', 'Erqah HU', 'SHABWA-RUDUM-ERQAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حورة الساحل', 'Hawrat As Sahel HU', 'SHABWA-RUDUM-HAWRATASSA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حورة العلياء', 'Hoorah Al Olya HC', 'SHABWA-RUDUM-HOORAHALOL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جلعة', 'Jlaah HU', 'SHABWA-RUDUM-JLAAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مدرم', 'Madram HU', 'SHABWA-RUDUM-MADRAMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفولة رضوم', 'Rodhoom Maternity & Childhood Center', 'SHABWA-RUDUM-RODHOOMMAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-RUDUM' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الغميس', 'AL Ghumyes HC', 'SHABWA-USAYLA-ALGHUMYESH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الهيشة', 'Al Haishah HU', 'SHABWA-USAYLA-ALHAISHAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحمى', 'Al Homa HU', 'SHABWA-USAYLA-ALHOMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجيف', 'Al Jiaf HU', 'SHABWA-USAYLA-ALJIAFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي النقوب', 'Al Nuqub HC', 'SHABWA-USAYLA-ALNUQUBHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ارة', 'Arah HU', 'SHABWA-USAYLA-ARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عسيلان', 'Osailan HU', 'SHABWA-USAYLA-OSAILANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى عسيلان', 'Osilan H', 'SHABWA-USAYLA-OSILANH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SHABWA-USAYLA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عادل', 'Adel HU', 'SOCOTR-HIDAYB-ADELHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دكشتن', 'Dakshan HU', 'SOCOTR-HIDAYB-DAKSHANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي ديحمض', 'Dehemdh HC', 'SOCOTR-HIDAYB-DEHEMDHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي دكسم', 'Duksum HC', 'SOCOTR-HIDAYB-DUKSUMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حي السلام', 'Haialsalam HU', 'SOCOTR-HIDAYB-HAIALSALAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حاله', 'Hala HU', 'SOCOTR-HIDAYB-HALAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حومهل', 'Homhel HU', 'SOCOTR-HIDAYB-HOMHELHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية إرسل', 'Irsal HU', 'SOCOTR-HIDAYB-IRSALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قعرة', 'Ka''ara HU', 'SOCOTR-HIDAYB-KA''''ARAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي قاضب', 'Kadheb HC', 'SOCOTR-HIDAYB-KADHEBHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي قرية', 'Karya HC', 'SOCOTR-HIDAYB-KARYAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى خليفة بن زايد', 'Khalifah Bin Zaid  H', 'SOCOTR-HIDAYB-KHALIFAHBI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله حديبو', 'Maternity & Childhood Hidaybu HC', 'SOCOTR-HIDAYB-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مطيف', 'Matiaf HU', 'SOCOTR-HIDAYB-MATIAFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية مومي', 'Mumi HU', 'SOCOTR-HIDAYB-MUMIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي نوجد', 'Nawjad HC', 'SOCOTR-HIDAYB-NAWJADHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سيهون', 'Saihon HU', 'SOCOTR-HIDAYB-SAIHONHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سيكو', 'Saiko HU', 'SOCOTR-HIDAYB-SAIKOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سلمهو', 'Salmho HU', 'SOCOTR-HIDAYB-SALMHOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شيزاب', 'Shazib HU', 'SOCOTR-HIDAYB-SHAZIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ستاره', 'Starh HU', 'SOCOTR-HIDAYB-STARHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية زاحق', 'Zahq HU', 'SOCOTR-HIDAYB-ZAHQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-HIDAYB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي عمدهن', 'Amdhen HC', 'SOCOTR-QULENS-AMDHENHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-QULENS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية دركبو', 'Darkabo HU', 'SOCOTR-QULENS-DARKABOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-QULENS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفولة قلنسسة', 'Maternity & Childhood Qalansya HC', 'SOCOTR-QULENS-MATERNITY&' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-QULENS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية قشاننة', 'Qishanah HU', 'SOCOTR-QULENS-QISHANAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'SOCOTR-QULENS' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة المخاء', 'AL Mukha Maternity & Childhood Center', 'TAIZZ-ALMUKH-ALMUKHAMAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الساحرة عزان', 'AL Saherah  Azan HU', 'TAIZZ-ALMUKH-ALSAHERAHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعامره', 'AL ma''amerah HU', 'TAIZZ-ALMUKH-ALMA''''AMER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشاذلية', 'AL shadliah HU', 'TAIZZ-ALMUKH-ALSHADLIAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بالغرافي', 'Alghrafi HC', 'TAIZZ-ALMUKH-ALGHRAFIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الجمعه', 'Aljumah HC', 'TAIZZ-ALMUKH-ALJUMAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه الكديحه', 'Alkdiha HU', 'TAIZZ-ALMUKH-ALKDIHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بالنجيبه', 'Alnjibh HU', 'TAIZZ-ALMUKH-ALNJIBHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه بالثوباني', 'Althwbani HU', 'TAIZZ-ALMUKH-ALTHWBANIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحيه بالزهاري', 'Alzhari HU', 'TAIZZ-ALMUKH-ALZHARIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه حسي سالم', 'Hasi Salm HU', 'TAIZZ-ALMUKH-HASISALMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه بربع جحزر', 'Jhzr HU', 'TAIZZ-ALMUKH-JHZRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي يختل', 'Ykhtl HC', 'TAIZZ-ALMUKH-YKHTLHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUKH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى 22 مايو', '22 May HC', 'TAIZZ-ALMA''''A-22MAYHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه 7 يوليو', '7 July HU', 'TAIZZ-ALMA''''A-7JULYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى ابن سيناء - المشاولة', 'Abn Sinaa Almshwlh HC', 'TAIZZ-ALMA''''A-ABNSINAAAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه العبلي', 'Al Aibaili HU', 'TAIZZ-ALMA''''A-ALAIBAILIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية  البيرين', 'Al BerianHU', 'TAIZZ-ALMA''''A-ALBERIANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الكاذية', 'Al Kadhiah HU', 'TAIZZ-ALMA''''A-ALKADHIAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية المكارسة', 'Al Mkarsah HU', 'TAIZZ-ALMA''''A-ALMKARSAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرهبوة', 'Al rahbua HU', 'TAIZZ-ALMA''''A-ALRAHBUAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الجرجور', 'Alajarjor HU', 'TAIZZ-ALMA''''A-ALAJARJORH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الهياب', 'Alhiab HC', 'TAIZZ-ALMA''''A-ALHIABHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الجبزية', 'Aljbzih HU', 'TAIZZ-ALMA''''A-ALJBZIHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى الخيامي', 'Alkhiami HC', 'TAIZZ-ALMA''''A-ALKHIAMIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى الكلائبة', 'Alklaaph HC', 'TAIZZ-ALMA''''A-ALKLAAPHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحبة الكريبية', 'Alkribiha HU', 'TAIZZ-ALMA''''A-ALKRIBIHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى النشمة الريفي', 'Alnshmh Rural H', 'TAIZZ-ALMA''''A-ALNSHMHRUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى الصنة', 'Alsnh HC', 'TAIZZ-ALMA''''A-ALSNHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحى الوحيز', 'Alwhiz HC', 'TAIZZ-ALMA''''A-ALWHIZHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية بر الوالدين', 'Biru Alwalidayn HU', 'TAIZZ-ALMA''''A-BIRUALWALI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه شرطوط', 'Shartot HU', 'TAIZZ-ALMA''''A-SHARTOTHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMA''A' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاهجوم', 'ALahgom HU', 'TAIZZ-ALMAWA-ALAHGOMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البطنه', 'ALbutnah HU', 'TAIZZ-ALMAWA-ALBUTNAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي الحوبان', 'Al Huban َQadas HC', 'TAIZZ-ALMAWA-ALHUBANَQA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجند', 'Al Junnid HU', 'TAIZZ-ALMAWA-ALJUNNIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المشجب', 'Al Mashjab HU', 'TAIZZ-ALMAWA-ALMASHJABH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه المكيشة', 'Al Mkaishah Hu', 'TAIZZ-ALMAWA-ALMKAISHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحد الصحية النباهنة', 'Al Nabahnh HU', 'TAIZZ-ALMAWA-ALNABAHNHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الشهيد عدنان الحمادي الريفي', 'Al Shaheed Adnan Al hamady Rural H', 'TAIZZ-ALMAWA-ALSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العجيل بني يوسف', 'Al eajil bani yusif HC', 'TAIZZ-ALMAWA-ALEAJILBAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  العين', 'Alain HC', 'TAIZZ-ALMAWA-ALAINHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاخمور', 'Alakhmur HC', 'TAIZZ-ALMAWA-ALAKHMURHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاشروح', 'Alashrouh HC', 'TAIZZ-ALMAWA-ALASHROUHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاصيلع', 'Alasila  HC', 'TAIZZ-ALMAWA-ALASILAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الدوم', 'Aldwm HC', 'TAIZZ-ALMAWA-ALDWMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى الكدرة الريفي', 'Alkadrh Rural H', 'TAIZZ-ALMAWA-ALKADRHRUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القحاف', 'Alqhaf HU', 'TAIZZ-ALMAWA-ALQHAFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصرم', 'Alsurm HU', 'TAIZZ-ALMAWA-ALSURMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الزبيرة', 'Alzubirh HC', 'TAIZZ-ALMAWA-ALZUBIRHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز السلام الطبي', 'As Salam HC', 'TAIZZ-ALMAWA-ASSALAMHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني عفيف', 'Bani Afif HU', 'TAIZZ-ALMAWA-BANIAFIFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي غبيرة', 'Ghbirh HC', 'TAIZZ-ALMAWA-GHBIRHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حزمان', 'Hazman HU', 'TAIZZ-ALMAWA-HAZMANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية حلقان', 'Hlqan HU', 'TAIZZ-ALMAWA-HLQANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي جرنات', 'Jranat HC', 'TAIZZ-ALMAWA-JRANATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي مطران', 'Matran  HC', 'TAIZZ-ALMAWA-MATRANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه عقف', 'Oqf HU', 'TAIZZ-ALMAWA-OQFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه صبن', 'Saban  HU', 'TAIZZ-ALMAWA-SABANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي شرار', 'Shrar HC', 'TAIZZ-ALMAWA-SHRARHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحبة وادي العجب', 'Wadi Al Ajab HU', 'TAIZZ-ALMAWA-WADIALAJAB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي زريد قدس', 'Zuraid Qadas HC', 'TAIZZ-ALMAWA-ZURAIDQADA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMAWA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه 7 يوليو المزهد', '7July Almzhd HU', 'TAIZZ-ALMISR-7JULYALMZH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي المطالي', 'Al Mutaly HC', 'TAIZZ-ALMISR-ALMUTALYHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشهيد محفوظ', 'Al shahid mahfuz HU', 'TAIZZ-ALMISR-ALSHAHIDMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية التعاون حجرين', 'Al taeawun hajarayn  HU', 'TAIZZ-ALMISR-ALTAEAWUNH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الوجيه', 'Al wajeeh HC', 'TAIZZ-ALMISR-ALWAJEEHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي الاقروض', 'Alaqroudh HC', 'TAIZZ-ALMISR-ALAQROUDHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى المسراخ الريفي', 'Almsrakh Rural H', 'TAIZZ-ALMISR-ALMSRAKHRU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرازي', 'Alrazi HC', 'TAIZZ-ALMISR-ALRAZIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد عبد العزيز (حيده)', 'Alshaid Abdulaziz (Hidah) HC', 'TAIZZ-ALMISR-ALSHAIDABD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي التعاون وتير', 'Altawn  Wtir HC', 'TAIZZ-ALMISR-ALTAWNWTIR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه انبيان', 'Anbian HU', 'TAIZZ-ALMISR-ANBIANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشوري اكمة حبيش', 'Ash Shoraa Akamah Habish HC', 'TAIZZ-ALMISR-ASHSHORAAA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الطيب جاره', 'At Taib Jarh HU', 'TAIZZ-ALMISR-ATTAIBJARH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه بني عباد وتير', 'Bani Aubad Watir HU', 'TAIZZ-ALMISR-BANIAUBADW' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي بلعان', 'Bilean HC', 'TAIZZ-ALMISR-BILEANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز حماه الصحي للامومه والطفولة', 'Hamh HC for Maternity & Childhood', 'TAIZZ-ALMISR-HAMHHCFORM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه حصبان', 'Hassbanh HU', 'TAIZZ-ALMISR-HASSBANHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبا', 'Japa HU', 'TAIZZ-ALMISR-JAPAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية صنمات', 'Sanemat  HU', 'TAIZZ-ALMISR-SANEMATHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه طالوق', 'Talouq HU', 'TAIZZ-ALMISR-TALOUQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحيه الوجد', 'al Wajd HU', 'TAIZZ-ALMISR-ALWAJDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاكدان', 'alacdan HU', 'TAIZZ-ALMISR-ALACDANHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد عبد السلام', 'alshaheed abdoalsalaam jaba   HC', 'TAIZZ-ALMISR-ALSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMISR' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي 22 مايو', '22 May HC', 'TAIZZ-ALMUDH-22MAYHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الضربة', 'Al Darba HC', 'TAIZZ-ALMUDH-ALDARBAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفي المظفر للامومة والطفولة', 'Al Modhafar H Mother & child', 'TAIZZ-ALMUDH-ALMODHAFAR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الثوره', 'Al Thowrah HC', 'TAIZZ-ALMUDH-ALTHOWRAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الوفاء', 'Al Wafaa HC', 'TAIZZ-ALMUDH-ALWAFAAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد اللقية', 'As Shaheed Al Laqiah HC', 'TAIZZ-ALMUDH-ASSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الامراض الجلدية', 'Dermatic Diseases H', 'TAIZZ-ALMUDH-DERMATICDI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي صينة', 'Saniah HC', 'TAIZZ-ALMUDH-SANIAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALMUDH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز 14 اكتوبر  للامومة والطفولة', '14 October Maternity & Childhood Center', 'TAIZZ-ALQAHI-14OCTOBERM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز 22 مايو للامومة والطفولة', '22May Maternity & Childhood Center', 'TAIZZ-ALQAHI-22MAYMATER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز 26 سبتمبر  للامومة والطفولة', '26 September Maternity & Childhood Center', 'TAIZZ-ALQAHI-26SEPTEMBE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الضبوعه', 'Al Dabueuh HU', 'TAIZZ-ALQAHI-ALDABUEUHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة االصحية المفتش', 'Al Mofatesh HU', 'TAIZZ-ALQAHI-ALMOFATESH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الجمهوري التعليمي العام', 'Aljoumhri H', 'TAIZZ-ALQAHI-ALJOUMHRIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفى التعاون', 'Altawn  H', 'TAIZZ-ALQAHI-ALTAWNH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى اليمني السويدي للأمومة والطفولة', 'Yemeni swedish H For Maternity & Childhood', 'TAIZZ-ALQAHI-YEMENISWED' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALQAHI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الغريف', 'Al Gharieef HU', 'TAIZZ-ALWAZI-ALGHARIEEF' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجريب', 'Al Jareeb HU', 'TAIZZ-ALWAZI-ALJAREEBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الردف', 'Al radf HU', 'TAIZZ-ALWAZI-ALRADFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاحيوق', 'Alahyoq HC', 'TAIZZ-ALWAZI-ALAHYOQHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الظريفة', 'Aldhrifh HC', 'TAIZZ-ALWAZI-ALDHRIFHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية البوكرة', 'Alpoukrh HU', 'TAIZZ-ALWAZI-ALPOUKRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القوبه', 'Alqwph HU', 'TAIZZ-ALWAZI-ALQWPHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشقيراء', 'Alshqira HC', 'TAIZZ-ALWAZI-ALSHQIRAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصنمة', 'Alsnmh HU', 'TAIZZ-ALWAZI-ALSNMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية غيل الحاضنة', 'Gheel Alhadhnh HU', 'TAIZZ-ALWAZI-GHEELALHAD' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حنة', 'Hanh HU', 'TAIZZ-ALWAZI-HANHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية شعبوا', 'Shapoo HU', 'TAIZZ-ALWAZI-SHAPOOHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ALWAZI' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المكوئ', 'AL makwi HU', 'TAIZZ-ASSILW-ALMAKWIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الأشعوب', 'Al Ashaoob HU', 'TAIZZ-ASSILW-ALASHAOOBH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  الحقيب الصحية', 'Al Hakaib HU', 'TAIZZ-ASSILW-ALHAKAIBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخير', 'Al Khair HU', 'TAIZZ-ASSILW-ALKHAIRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العكيشه', 'Alakisha HC', 'TAIZZ-ASSILW-ALAKISHAHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاقصي', 'Alaqssa Alssaid HU', 'TAIZZ-ASSILW-ALAQSSAALS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحئ الفاروق', 'Alfarouq HC', 'TAIZZ-ASSILW-ALFAROUQHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحئ القابلة', 'Alqaplah HC', 'TAIZZ-ASSILW-ALQAPLAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي القطين', 'Alqotain HC', 'TAIZZ-ASSILW-ALQOTAINHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفى الريفي الثوره', 'Althwrh H', 'TAIZZ-ASSILW-ALTHWRHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الودر', 'Alwdr HU', 'TAIZZ-ASSILW-ALWDRHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبك', 'Habak HU', 'TAIZZ-ASSILW-HABAKHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية قراضة', 'Kradhah HU', 'TAIZZ-ASSILW-KRADHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سائله الأوراث', 'Saelh Alaorath HU', 'TAIZZ-ASSILW-SAELHALAOR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASSILW' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي  30نوفمبر زعازع', '30 Novamber Alzaaza HC', 'TAIZZ-ASHSHA-30NOVAMBER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخير زعازع', 'ALkheer za''azia HU', 'TAIZZ-ASHSHA-ALKHEERZA''' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الكباب', 'Al Kabab Dhobanah HU', 'TAIZZ-ASHSHA-ALKABABDHO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده  الصحية المشارقه', 'Al Msharikah HU', 'TAIZZ-ASHSHA-ALMSHARIKA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة السويقة الصحية - بني شيبة الشرق', 'Al Suwayqah HU - Bani Shaibah Al Sharq', 'TAIZZ-ASHSHA-ALSUWAYQAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  الامل اخينه زعازع', 'Alaml Akhinh Zaaza HU', 'TAIZZ-ASHSHA-ALAMLAKHIN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  الغزالي', 'Alghzali HC', 'TAIZZ-ASHSHA-ALGHZALIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي المنصوره', 'Almansurh HC', 'TAIZZ-ASHSHA-ALMANSURHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المدهف', 'Almdhf HU', 'TAIZZ-ASHSHA-ALMDHFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي المقارمه', 'Almqarmh HC', 'TAIZZ-ASHSHA-ALMQARMHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي  المساحين', 'Almsahin HC', 'TAIZZ-ASHSHA-ALMSAHINHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي البذيجه الكويره', 'Alpthiha Alkuirh HC', 'TAIZZ-ASHSHA-ALPTHIHAAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكويره', 'Alqwirh HU', 'TAIZZ-ASHSHA-ALQWIRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي  الرجمه اصابح', 'Alrhmh Assaph HC', 'TAIZZ-ASHSHA-ALRHMHASSA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرجاعيه', 'Alrjaaih HC', 'TAIZZ-ASHSHA-ALRJAAIHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الطيب شرجب', 'Altib Shrjb HU', 'TAIZZ-ASHSHA-ALTIBSHRJB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومه والطفوله التربة', 'Alturph Maternity & Childhood Center', 'TAIZZ-ASHSHA-ALTURPHMAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الزكيره', 'Alzakirh HU', 'TAIZZ-ASHSHA-ALZAKIRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشهيد القيفي', 'As Shaheed Al Gaifi HU', 'TAIZZ-ASHSHA-ASSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  الصنعه زريقه', 'As Shaniaah Rozaik HU', 'TAIZZ-ASHSHA-ASSHANIAAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني مسن', 'Bani Masn HU', 'TAIZZ-ASHSHA-BANIMASNHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  بني شيبه الغرب', 'Bani Shibh Alghrb  HU', 'TAIZZ-ASHSHA-BANISHIBHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  بندح القاهر', 'Banidah Al Ghaher HU', 'TAIZZ-ASHSHA-BANIDAHALG' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بني محمد', 'Bni Mohammed HC', 'TAIZZ-ASHSHA-BNIMOHAMME' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بني عمر', 'Bni Omr HC', 'TAIZZ-ASHSHA-BNIOMRHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المستشفي الريفي بني شيبه الشرق', 'Bni Shiph Alshrq Rural H', 'TAIZZ-ASHSHA-BNISHIPHAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية برج الخبطان', 'Borj Khabtan HU', 'TAIZZ-ASHSHA-BORJKHABTA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي  راسن', 'Dasn HC', 'TAIZZ-ASHSHA-DASNHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي دبع الداخل', 'Duba Aldakhl HC', 'TAIZZ-ASHSHA-DUBAALDAKH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي فرجة اديم (اديم حضارم)', 'Frjh Adim (Adim Hadarem) HC', 'TAIZZ-ASHSHA-FRJHADIM(A' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حيب اصابح', 'Hib asabh HC', 'TAIZZ-ASHSHA-HIBASABHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية جرداد بني عمر', 'Jrdad Bni Omar HU', 'TAIZZ-ASHSHA-JRDADBNIOM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الخبل علقمه', 'Khabal Algam HU', 'TAIZZ-ASHSHA-KHABALALGA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بطان مذاحج اسفل', 'Mdahj Asfl HC', 'TAIZZ-ASHSHA-MDAHJASFLH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي منيف قريشه', 'Munif Quraisha HC', 'TAIZZ-ASHSHA-MUNIFQURAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عهده ذبحان', 'Ohdaht Dhoban HU', 'TAIZZ-ASHSHA-OHDAHTDHOB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي رفيده السمسره', 'Rufidh Alsamsarh HC', 'TAIZZ-ASHSHA-RUFIDHALSA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية  شباعه عزاعز', 'Shbaah Azaez HU', 'TAIZZ-ASHSHA-SHBAAHAZAE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية وادي عرفات', 'Wadi Arafat HU', 'TAIZZ-ASHSHA-WADIARAFAT' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي وادي الصحاء ألقريشه', 'Wadi As Shahaa Alqraisha HC', 'TAIZZ-ASHSHA-WADIASSHAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية وادي تب علقمه', 'Wadi Toup Alalqamh  HU', 'TAIZZ-ASHSHA-WADITOUPAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-ASHSHA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الكدحة', 'ALkadha HU', 'TAIZZ-DHUBAB-ALKADHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الرواع', 'ALrawie HC', 'TAIZZ-DHUBAB-ALRAWIEHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي واحجة', 'ALwahjh HC', 'TAIZZ-DHUBAB-ALWAHJHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العرضي', 'Al Ordhai HU', 'TAIZZ-DHUBAB-ALORDHAIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الجديد', 'Aljdid HC', 'TAIZZ-DHUBAB-ALJDIDHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفي ذو باب', 'Dhubab H', 'TAIZZ-DHUBAB-DHUBABH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية غريره', 'Ghrirh HU', 'TAIZZ-DHUBAB-GHRIRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-DHUBAB' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العدف', 'ALadef HU', 'TAIZZ-JABALH-ALADEFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المشجب', 'ALmushgub HU', 'TAIZZ-JABALH-ALMUSHGUBH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد علي سلطان', 'ALshaheed Ali sultan HC', 'TAIZZ-JABALH-ALSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العجف', 'ALugf HC', 'TAIZZ-JABALH-ALUGFHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية عدينة', 'Adinh HU', 'TAIZZ-JABALH-ADINHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العفيره', 'Al Afairah HU', 'TAIZZ-JABALH-ALAFAIRAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية  قشيبه', 'Al Aml GshaibahHU  HU', 'TAIZZ-JABALH-ALAMLGSHAI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العراري', 'Al Earari HC', 'TAIZZ-JABALH-ALEARARIHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الغزاليه', 'Al Ghazaliah HC', 'TAIZZ-JABALH-ALGHAZALIA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحدادين', 'Al Hadadin HU', 'TAIZZ-JABALH-ALHADADINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجند الاسفل', 'Al Jnad al asfl HU', 'TAIZZ-JABALH-ALJNADALAS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القبة شراجة', 'Al Kobah AlShraja HU', 'TAIZZ-JABALH-ALKOBAHALS' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدةالصحية المحمل', 'Al Mahmal HU', 'TAIZZ-JABALH-ALMAHMALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المبهاء', 'Al Mbhaa HU', 'TAIZZ-JABALH-ALMBHAAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المستقبل', 'Al Mustaqbal HU', 'TAIZZ-JABALH-ALMUSTAQBA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المزبار', 'Al Mzbar HU', 'TAIZZ-JABALH-ALMZBARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرحبه', 'Al Rahbah HC', 'TAIZZ-JABALH-ALRAHBAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الضياء', 'Al dhia HU', 'TAIZZ-JABALH-ALDHIAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد عبدالله حسان', 'Al shahid Abdullah Hassan HC', 'TAIZZ-JABALH-ALSHAHIDAB' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الاشروح', 'Alashrouh HC', 'TAIZZ-JABALH-ALASHROUHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية البريهة', 'Albrihah HU', 'TAIZZ-JABALH-ALBRIHAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجرف', 'Algurf HU', 'TAIZZ-JABALH-ALGURFHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحقل', 'Alhaql HU', 'TAIZZ-JABALH-ALHAQLHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخلفة', 'Alkhlfh HU', 'TAIZZ-JABALH-ALKHLFHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية السعيد', 'Alsaid HU', 'TAIZZ-JABALH-ALSAIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشارق', 'Alsharq HU', 'TAIZZ-JABALH-ALSHARQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشراجة عكاد', 'Alshrajh  Aakaad HU', 'TAIZZ-JABALH-ALSHRAJHAA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني بكاري', 'Bani Bukari HU', 'TAIZZ-JABALH-BANIBUKARI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني جعفر', 'Bani Jaffer HU', 'TAIZZ-JABALH-BANIJAFFER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني خيله', 'Bany khailah HU', 'TAIZZ-JABALH-BANYKHAILA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بلاد الوافي', 'Blad Alwafi HC', 'TAIZZ-JABALH-BLADALWAFI' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حجرمين', 'HajraMin HU', 'TAIZZ-JABALH-HAJRAMINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حراز', 'Heraz HU', 'TAIZZ-JABALH-HERAZHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية كزم', 'Kuzm HU', 'TAIZZ-JABALH-KUZMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه مدهافة', 'Medhafa HU', 'TAIZZ-JABALH-MEDHAFAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد محمد الدره', 'Mohammed Aldorah HC', 'TAIZZ-JABALH-MOHAMMEDAL' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نمره', 'Namerah HU', 'TAIZZ-JABALH-NAMERAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نقيل المنعم', 'Naqeel Almunem HU', 'TAIZZ-JABALH-NAQEELALMU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية نجد العود', 'Njd Alawd HU', 'TAIZZ-JABALH-NJDALAWDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحيه صهيب العامري', 'Suhaib Alamery HU', 'TAIZZ-JABALH-SUHAIBALAM' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشيخ طه سعيد', 'Taha Saeed HC', 'TAIZZ-JABALH-TAHASAEEDH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي التعاون برحات', 'Tawan brahat HC', 'TAIZZ-JABALH-TAWANBRAHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الوادي الاحمر', 'Wadi Alahmr HU', 'TAIZZ-JABALH-WADIALAHMR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي وادي البير', 'Wadi Albeer HC', 'TAIZZ-JABALH-WADIALBEER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي يفرس', 'Yfrous HC', 'TAIZZ-JABALH-YFROUSHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية فجر الامل', 'fajar alamal HU', 'TAIZZ-JABALH-FAJARALAMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-JABALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية البوامية', 'Al Bomiah HU', 'TAIZZ-MAQBAN-ALBOMIAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحصبري', 'Al Hasbari HU', 'TAIZZ-MAQBAN-ALHASBARIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشهيد البركاني -المضابي', 'Al Shaheed Al Barkani HC', 'TAIZZ-MAQBAN-ALSHAHEEDA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العفيرة', 'Alafirah HC', 'TAIZZ-MAQBAN-ALAFIRAHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفكيكة', 'Alfakikah HC', 'TAIZZ-MAQBAN-ALFAKIKAHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية  البراشة', 'Alprasha HU', 'TAIZZ-MAQBAN-ALPRASHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي حمير الجبل', 'Hameer Aljpal HC', 'TAIZZ-MAQBAN-HAMEERALJP' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAQBAN' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الخير المحرس', 'Al Kair Al Mhras HU', 'TAIZZ-MASHRA-ALKAIRALMH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الكشار', 'Al Kshar HU', 'TAIZZ-MASHRA-ALKSHARHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية الميهال', 'Al Mihal HU', 'TAIZZ-MASHRA-ALMIHALHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاوشاني', 'Alaoshani HU', 'TAIZZ-MASHRA-ALAOSHANIH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الفتح', 'Alfath HC', 'TAIZZ-MASHRA-ALFATHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المفيتيح نمة', 'Almfitih Nemha HU', 'TAIZZ-MASHRA-ALMFITIHNE' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة  الصحية السعيد', 'Alsaid HU', 'TAIZZ-MASHRA-ALSAIDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الشفاء حدنان', 'Alshifaa Hadnan HC', 'TAIZZ-MASHRA-ALSHIFAAHA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية تبيح', 'Tabeeh HU', 'TAIZZ-MASHRA-TABEEHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MASHRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الجحفة', 'Al huhpha HU', 'TAIZZ-MAWZA-ALHUHPHAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العيصم', 'Alaism HU', 'TAIZZ-MAWZA-ALAISMHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العقمة', 'Alaqamh HU', 'TAIZZ-MAWZA-ALAQAMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الاتيمة', 'Alatimh HU', 'TAIZZ-MAWZA-ALATIMHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحد', 'Alhd HU', 'TAIZZ-MAWZA-ALHDHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصرارة', 'As Srarah HU', 'TAIZZ-MAWZA-ASSRARAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي جسر الهاملي', 'Jasr al Hamlil HC', 'TAIZZ-MAWZA-JASRALHAML' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز طوارئ مفرق المخاء', 'Mafriq Al Mukha HC', 'TAIZZ-MAWZA-MAFRIQALMU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مركز الامومة والطفولة موزع', 'Mawza Maternity & Childhood Center', 'TAIZZ-MAWZA-MAWZAMATER' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-MAWZA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 11 فبراير', '11 February HU', 'TAIZZ-SABIRA-11FEBRUARY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 22 مايو', '22 May HU', 'TAIZZ-SABIRA-22MAYHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 26 سبتمبر', '26 Sep HU', 'TAIZZ-SABIRA-26SEPHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشقب', 'ALshaqb HU', 'TAIZZ-SABIRA-ALSHAQBHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي التعاون', 'ALta''awn HC', 'TAIZZ-SABIRA-ALTA''''AWNH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفي العروس الريفي', 'Al Aroos Rural H', 'TAIZZ-SABIRA-ALAROOSRUR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الحياة عقاقة', 'Al Hayah Aqaqah HU', 'TAIZZ-SABIRA-ALHAYAHAQA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي العمرين', 'Al omareen HC', 'TAIZZ-SABIRA-ALOMAREENH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الامل', 'Alamal - HC', 'TAIZZ-SABIRA-ALAMAL-HC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية العنين سيعه', 'Alanin Seeah HU', 'TAIZZ-SABIRA-ALANINSEEA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الارشاد سيعه', 'Alarshd HC', 'TAIZZ-SABIRA-ALARSHDHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي الضباب', 'Aldhabab HC', 'TAIZZ-SABIRA-ALDHABABHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية المعقاب', 'Almaqab HU', 'TAIZZ-SABIRA-ALMAQABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النيداني', 'Alnidani HU', 'TAIZZ-SABIRA-ALNIDANIHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية النجاده', 'Alnjadh HU', 'TAIZZ-SABIRA-ALNJADHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي النور', 'Alnoor HC', 'TAIZZ-SABIRA-ALNOORHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الرحمه', 'Alrhmah HU', 'TAIZZ-SABIRA-ALRHMAHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الصرمين', 'As Sormain HU', 'TAIZZ-SABIRA-ASSORMAINH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الشفاء قراضه', 'Ash Shfaa Koradh  HU', 'TAIZZ-SABIRA-ASHSHFAAKO' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية برداد', 'Brdad HU', 'TAIZZ-SABIRA-BRDADHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذي مرين', 'Dhmrin HU', 'TAIZZ-SABIRA-DHMRINHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية حبيل سلمان', 'Habil Slman HU', 'TAIZZ-SABIRA-HABILSLMAN' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية ذي البرح', 'Thi Albrh HU', 'TAIZZ-SABIRA-THIALBRHHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SABIRA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'لمركز الصحي  11 فبراير', '11February HC', 'TAIZZ-SALH-11FEBRUARY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'مستشفي الثورة', 'Althwrh H', 'TAIZZ-SALH-ALTHWRHH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي 14 اكتوبر', 'October14 HC', 'TAIZZ-SALH-OCTOBER14H' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركزالصحي ثعبات', 'Thabat HC', 'TAIZZ-SALH-THABATHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SALH' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية 11 فبراير السلف', '11February Al Salf HU', 'TAIZZ-SAMA-11FEBRUARY' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي 22 مايو', '22 May HC', 'TAIZZ-SAMA-22MAYHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية القتب', 'Al Qatab HU', 'TAIZZ-SAMA-ALQATABHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الوادي شريع', 'Al Wadi Share''e HU', 'TAIZZ-SAMA-ALWADISHAR' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية الميثاق', 'Al mithaq HU', 'TAIZZ-SAMA-ALMITHAQHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية الخضراء', 'Alkhadraa HU', 'TAIZZ-SAMA-ALKHADRAAH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي النجيد', 'Alnjid HC', 'TAIZZ-SAMA-ALNJIDHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية بني احمد', 'Bani Ahmed HU', 'TAIZZ-SAMA-BANIAHMEDH' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي بكيان', 'Bokian HC', 'TAIZZ-SAMA-BOKIANHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحده الصحية دمنة سامع', 'Damnat Sama HU', 'TAIZZ-SAMA-DAMNATSAMA' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'المركز الصحي حورة', 'Hwrh HC', 'TAIZZ-SAMA-HWRHHC' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية جبل سامع', 'Jpal Sama HU', 'TAIZZ-SAMA-JPALSAMAHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'الوحدة الصحية سربيت', 'Srbit HU', 'TAIZZ-SAMA-SRBITHU' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;
INSERT INTO health_facilities (district_id, name_ar, name_en, code) SELECT d.id, 'وحدة حمان', 'وحدة حمان', 'TAIZZ-SAMA-وحدةحمان' FROM districts d JOIN governorates g ON d.governorate_id = g.id WHERE d.code = 'TAIZZ-SAMA' ON CONFLICT (code) DO NOTHING;

COMMIT;
