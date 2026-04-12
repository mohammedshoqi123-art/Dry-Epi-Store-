-- ============================================================
-- EPI Supervisor Platform - Complete Database Schema
-- Version: 1.0.1
-- Database: PostgreSQL (Supabase)
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'admin',
  'central',
  'governorate',
  'district',
  'data_entry'
);

CREATE TYPE submission_status AS ENUM (
  'draft',
  'submitted',
  'reviewed',
  'approved',
  'rejected'
);

CREATE TYPE shortage_severity AS ENUM (
  'critical',
  'high',
  'medium',
  'low'
);

CREATE TYPE audit_action AS ENUM (
  'create',
  'read',
  'update',
  'delete',
  'login',
  'logout',
  'submit',
  'approve',
  'reject',
  'export'
);

-- ============================================================
-- TABLE: governorates (must be BEFORE profiles due to FK)
-- ============================================================

CREATE TABLE governorates (
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

CREATE INDEX idx_governorates_code ON governorates(code) WHERE deleted_at IS NULL;
CREATE INDEX idx_governorates_geom ON governorates USING GIST(geometry);
CREATE INDEX idx_governorates_name_ar ON governorates USING gin(name_ar gin_trgm_ops);

COMMENT ON TABLE governorates IS 'Administrative governorate divisions';

-- ============================================================
-- TABLE: districts (must be BEFORE profiles due to FK)
-- ============================================================

CREATE TABLE districts (
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

CREATE INDEX idx_districts_governorate ON districts(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_districts_code ON districts(code) WHERE deleted_at IS NULL;
CREATE INDEX idx_districts_geom ON districts USING GIST(geometry);

COMMENT ON TABLE districts IS 'Administrative district divisions within governorates';

-- ============================================================
-- TABLE: profiles
-- ============================================================

CREATE TABLE profiles (
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

CREATE INDEX idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_governorate ON profiles(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_district ON profiles(district_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_email ON profiles(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_active ON profiles(is_active) WHERE deleted_at IS NULL;

COMMENT ON TABLE profiles IS 'User profiles with role-based access control';

-- ============================================================
-- TABLE: forms
-- ============================================================

CREATE TABLE forms (
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
  allowed_roles user_role[] NOT NULL DEFAULT ARRAY['data_entry', 'district', 'governorate', 'central', 'admin']::user_role[],
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,

  CONSTRAINT forms_schema_check CHECK (jsonb_typeof(schema) = 'object'),
  CONSTRAINT forms_title_check CHECK (length(title_ar) >= 2)
);

CREATE INDEX idx_forms_active ON forms(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_forms_created_by ON forms(created_by);
CREATE INDEX idx_forms_schema ON forms USING GIN(schema);

COMMENT ON TABLE forms IS 'Dynamic form definitions with JSON schema';

-- ============================================================
-- TABLE: form_submissions
-- ============================================================

CREATE TABLE form_submissions (
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

CREATE INDEX idx_submissions_form ON form_submissions(form_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_submitted_by ON form_submissions(submitted_by) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_status ON form_submissions(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_governorate ON form_submissions(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_district ON form_submissions(district_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_location ON form_submissions USING GIST(location);
CREATE INDEX idx_submissions_created ON form_submissions(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_data ON form_submissions USING GIN(data);
CREATE INDEX idx_submissions_offline ON form_submissions(offline_id) WHERE offline_id IS NOT NULL;

COMMENT ON TABLE form_submissions IS 'Form submission data with offline sync support';

-- ============================================================
-- TABLE: supply_shortages
-- ============================================================

CREATE TABLE supply_shortages (
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

CREATE INDEX idx_shortages_governorate ON supply_shortages(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_shortages_district ON supply_shortages(district_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_shortages_severity ON supply_shortages(severity) WHERE deleted_at IS NULL;
CREATE INDEX idx_shortages_resolved ON supply_shortages(is_resolved) WHERE deleted_at IS NULL;
CREATE INDEX idx_shortages_location ON supply_shortages USING GIST(location);
CREATE INDEX idx_shortages_item ON supply_shortages USING gin(item_name gin_trgm_ops);

COMMENT ON TABLE supply_shortages IS 'Supply shortage tracking with geo-location';

-- ============================================================
-- TABLE: audit_logs
-- ============================================================

CREATE TABLE audit_logs (
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

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_record ON audit_logs(record_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_session ON audit_logs(session_id);

COMMENT ON TABLE audit_logs IS 'Immutable audit trail for all system actions';

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_governorates_updated BEFORE UPDATE ON governorates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_districts_updated BEFORE UPDATE ON districts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_forms_updated BEFORE UPDATE ON forms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_submissions_updated BEFORE UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_shortages_updated BEFORE UPDATE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Audit log trigger function
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

-- Apply audit triggers
CREATE TRIGGER trg_profiles_audit AFTER INSERT OR UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_forms_audit AFTER INSERT OR UPDATE OR DELETE ON forms FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_submissions_audit AFTER INSERT OR UPDATE OR DELETE ON form_submissions FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_shortages_audit AFTER INSERT OR UPDATE OR DELETE ON supply_shortages FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Location auto-set trigger
CREATE OR REPLACE FUNCTION set_submission_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.gps_lat IS NOT NULL AND NEW.gps_lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.gps_lng, NEW.gps_lat), 4326);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_submission_location BEFORE INSERT OR UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION set_submission_location();

-- Profile auto-creation on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'data_entry')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_auth_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Role hierarchy check function
CREATE OR REPLACE FUNCTION check_role_hierarchy(target_role user_role, assigner_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  assigner_role user_role;
  hierarchy JSONB := '{
    "admin": 5,
    "central": 4,
    "governorate": 3,
    "district": 2,
    "data_entry": 1
  }';
BEGIN
  SELECT role INTO assigner_role FROM profiles WHERE id = assigner_id;
  RETURN (hierarchy->>assigner_role::TEXT)::INT > (hierarchy->>target_role::TEXT)::INT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_shortages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper function: get current user role
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper function: get current user governorate
CREATE OR REPLACE FUNCTION auth.user_governorate_id()
RETURNS UUID AS $$
  SELECT governorate_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper function: get current user district
CREATE OR REPLACE FUNCTION auth.user_district_id()
RETURNS UUID AS $$
  SELECT district_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ---- PROFILES RLS ----

CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (auth.user_role() = 'admin');

CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "profiles_select_central" ON profiles
  FOR SELECT USING (auth.user_role() = 'central');

CREATE POLICY "profiles_select_governorate" ON profiles
  FOR SELECT USING (
    auth.user_role() = 'governorate' AND
    governorate_id = auth.user_governorate_id()
  );

CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (auth.user_role() = 'admin');

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (auth.user_role() = 'admin');

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (id = auth.uid());

-- ---- GOVERNORATES RLS ----

CREATE POLICY "governorates_select_all" ON governorates
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "governorates_modify_admin" ON governorates
  FOR ALL USING (auth.user_role() = 'admin');

-- ---- DISTRICTS RLS ----

CREATE POLICY "districts_select_all" ON districts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "districts_modify_admin" ON districts
  FOR ALL USING (auth.user_role() = 'admin');

-- ---- FORMS RLS ----

CREATE POLICY "forms_select_all" ON forms
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "forms_select_admin" ON forms
  FOR SELECT USING (auth.user_role() = 'admin');

CREATE POLICY "forms_modify_admin" ON forms
  FOR ALL USING (auth.user_role() = 'admin');

-- ---- FORM_SUBMISSIONS RLS ----

CREATE POLICY "submissions_select_own" ON form_submissions
  FOR SELECT USING (submitted_by = auth.uid());

CREATE POLICY "submissions_select_district" ON form_submissions
  FOR SELECT USING (
    auth.user_role() = 'district' AND
    district_id = auth.user_district_id()
  );

CREATE POLICY "submissions_select_governorate" ON form_submissions
  FOR SELECT USING (
    auth.user_role() = 'governorate' AND
    governorate_id = auth.user_governorate_id()
  );

CREATE POLICY "submissions_select_central_admin" ON form_submissions
  FOR SELECT USING (auth.user_role() IN ('central', 'admin'));

CREATE POLICY "submissions_insert_own" ON form_submissions
  FOR INSERT WITH CHECK (
    submitted_by = auth.uid() AND
    auth.user_role() IN ('data_entry', 'district', 'governorate', 'central', 'admin')
  );

CREATE POLICY "submissions_update_own_draft" ON form_submissions
  FOR UPDATE USING (
    submitted_by = auth.uid() AND status = 'draft'
  );

CREATE POLICY "submissions_update_reviewer" ON form_submissions
  FOR UPDATE USING (
    auth.user_role() = 'admin' OR
    auth.user_role() = 'central' OR
    (auth.user_role() = 'governorate' AND governorate_id = auth.user_governorate_id()) OR
    (auth.user_role() = 'district' AND district_id = auth.user_district_id())
  );

-- ---- SUPPLY_SHORTAGES RLS ----

CREATE POLICY "shortages_select_all_auth" ON supply_shortages
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "shortages_insert_auth" ON supply_shortages
  FOR INSERT WITH CHECK (reported_by = auth.uid());

CREATE POLICY "shortages_update_hierarchy" ON supply_shortages
  FOR UPDATE USING (
    reported_by = auth.uid() OR
    auth.user_role() IN ('district', 'governorate', 'central', 'admin')
  );

-- ---- AUDIT_LOGS RLS ----

CREATE POLICY "audit_select_admin" ON audit_logs
  FOR SELECT USING (auth.user_role() = 'admin');

CREATE POLICY "audit_select_central" ON audit_logs
  FOR SELECT USING (auth.user_role() = 'central');

CREATE POLICY "audit_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- No update/delete on audit logs (immutable)

-- ============================================================
-- END OF SCHEMA
-- ============================================================
