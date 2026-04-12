-- ============================================================
-- EPI Supervisor Platform — COMPLETE MIGRATION (Single File)
-- انسخ كل محتوى هذا الملف والصقه في Supabase SQL Editor واضغط Run
-- ============================================================
-- شغّل هذا الملف مرة واحدة فقط على قاعدة بيانات جديدة
-- Run this file ONCE on a fresh Supabase database
-- ============================================================

BEGIN;

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 1: EXTENSIONS                                      ║
-- ╚═══════════════════════════════════════════════════════════╝

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 2: ENUMS                                           ║
-- ╚═══════════════════════════════════════════════════════════╝

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

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 3: TABLES                                          ║
-- ╚═══════════════════════════════════════════════════════════╝

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

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 4: INDEXES                                         ║
-- ╚═══════════════════════════════════════════════════════════╝

CREATE INDEX IF NOT EXISTS idx_governorates_code ON governorates(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_governorates_geom ON governorates USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_governorates_name_ar ON governorates USING gin(name_ar gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_districts_governorate ON districts(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_code ON districts(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_districts_geom ON districts USING GIST(geometry);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_governorate ON profiles(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_district ON profiles(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_active ON profiles(is_active) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_forms_active ON forms(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_forms_created_by ON forms(created_by);
CREATE INDEX IF NOT EXISTS idx_forms_schema ON forms USING GIN(schema);

CREATE INDEX IF NOT EXISTS idx_submissions_form ON form_submissions(form_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_by ON form_submissions(submitted_by) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_governorate ON form_submissions(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_district ON form_submissions(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_location ON form_submissions USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_submissions_created ON form_submissions(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_data ON form_submissions USING GIN(data);
CREATE INDEX IF NOT EXISTS idx_submissions_offline ON form_submissions(offline_id) WHERE offline_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shortages_governorate ON supply_shortages(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_district ON supply_shortages(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_severity ON supply_shortages(severity) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_resolved ON supply_shortages(is_resolved) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shortages_location ON supply_shortages USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_shortages_item ON supply_shortages USING gin(item_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_logs(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_logs(session_id);

CREATE INDEX IF NOT EXISTS idx_facilities_district ON health_facilities(district_id) WHERE deleted_at IS NULL;

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 5: HELPER FUNCTIONS                                ║
-- ╚═══════════════════════════════════════════════════════════╝

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

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 6: ROW LEVEL SECURITY                              ║
-- ╚═══════════════════════════════════════════════════════════╝

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_shortages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_facilities ENABLE ROW LEVEL SECURITY;

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

DROP POLICY IF EXISTS "facilities_select_all" ON health_facilities;
DROP POLICY IF EXISTS "facilities_modify_admin" ON health_facilities;

-- PROFILES
CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_insert_admin" ON profiles FOR INSERT WITH CHECK (public.user_role() = 'admin');
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_select_admin" ON profiles FOR SELECT USING (public.user_role() = 'admin');
CREATE POLICY "profiles_select_central" ON profiles FOR SELECT USING (public.user_role() = 'central');
CREATE POLICY "profiles_select_governorate" ON profiles FOR SELECT USING (
  public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()
);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (public.user_role() = 'admin');

-- GOVERNORATES
CREATE POLICY "governorates_select_all" ON governorates FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "governorates_modify_admin" ON governorates FOR ALL USING (public.user_role() = 'admin');

-- DISTRICTS
CREATE POLICY "districts_select_all" ON districts FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "districts_modify_admin" ON districts FOR ALL USING (public.user_role() = 'admin');

-- FORMS
CREATE POLICY "forms_select_all" ON forms FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
CREATE POLICY "forms_select_admin" ON forms FOR SELECT USING (public.user_role() = 'admin');
CREATE POLICY "forms_modify_admin" ON forms FOR ALL USING (public.user_role() = 'admin');

-- FORM_SUBMISSIONS
CREATE POLICY "submissions_select_own" ON form_submissions FOR SELECT USING (submitted_by = auth.uid());
CREATE POLICY "submissions_select_district" ON form_submissions FOR SELECT USING (
  public.user_role() = 'district' AND district_id = public.user_district_id()
);
CREATE POLICY "submissions_select_governorate" ON form_submissions FOR SELECT USING (
  public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()
);
CREATE POLICY "submissions_select_central_admin" ON form_submissions FOR SELECT USING (public.user_role() IN ('central', 'admin'));
CREATE POLICY "submissions_insert_own" ON form_submissions FOR INSERT WITH CHECK (
  submitted_by = auth.uid() AND public.user_role() IN ('data_entry', 'district', 'governorate', 'central', 'admin')
);
CREATE POLICY "submissions_update_own_draft" ON form_submissions FOR UPDATE USING (submitted_by = auth.uid() AND status = 'draft');
CREATE POLICY "submissions_update_reviewer" ON form_submissions FOR UPDATE USING (
  public.user_role() = 'admin' OR public.user_role() = 'central' OR
  (public.user_role() = 'governorate' AND governorate_id = public.user_governorate_id()) OR
  (public.user_role() = 'district' AND district_id = public.user_district_id())
);

-- SUPPLY_SHORTAGES
CREATE POLICY "shortages_select_all_auth" ON supply_shortages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "shortages_insert_auth" ON supply_shortages FOR INSERT WITH CHECK (reported_by = auth.uid());
CREATE POLICY "shortages_update_hierarchy" ON supply_shortages FOR UPDATE USING (
  reported_by = auth.uid() OR public.user_role() IN ('district', 'governorate', 'central', 'admin')
);

-- AUDIT_LOGS
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT USING (public.user_role() = 'admin');
CREATE POLICY "audit_select_central" ON audit_logs FOR SELECT USING (public.user_role() = 'central');
CREATE POLICY "audit_insert_system" ON audit_logs FOR INSERT WITH CHECK (true);

-- HEALTH_FACILITIES
CREATE POLICY "facilities_select_all" ON health_facilities FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "facilities_modify_admin" ON health_facilities FOR ALL USING (public.user_role() = 'admin');

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 7: TRIGGER FUNCTIONS                               ║
-- ╚═══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION set_submission_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.gps_lat IS NOT NULL AND NEW.gps_lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.gps_lng, NEW.gps_lat), 4326);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 8: APPLY TRIGGERS                                  ║
-- ╚═══════════════════════════════════════════════════════════╝

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

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 9: SEED DATA — Iraqi Governorates & Districts      ║
-- ╚═══════════════════════════════════════════════════════════╝

INSERT INTO governorates (id, name_ar, name_en, code, center_lat, center_lng) VALUES
  (uuid_generate_v4(), 'بغداد', 'Baghdad', 'BGD', 33.3152, 44.3661),
  (uuid_generate_v4(), 'البصرة', 'Basra', 'BSR', 30.5085, 47.7804),
  (uuid_generate_v4(), 'أربيل', 'Erbil', 'ERB', 36.1911, 44.0092),
  (uuid_generate_v4(), 'الموصل', 'Mosul', 'MSL', 36.3350, 43.1189),
  (uuid_generate_v4(), 'النجف', 'Najaf', 'NJF', 32.0282, 44.3391),
  (uuid_generate_v4(), 'كركوك', 'Kirkuk', 'KRK', 35.4681, 44.3922),
  (uuid_generate_v4(), 'ذي قار', 'Dhi Qar', 'DQR', 31.0375, 46.2583),
  (uuid_generate_v4(), 'الأنبار', 'Anbar', 'ANB', 33.4211, 43.3033),
  (uuid_generate_v4(), 'ديالى', 'Diyala', 'DYL', 33.7500, 45.0000),
  (uuid_generate_v4(), 'صلاح الدين', 'Saladin', 'SLD', 34.6000, 43.6800),
  (uuid_generate_v4(), 'بابل', 'Babylon', 'BBN', 32.4833, 44.4333),
  (uuid_generate_v4(), 'كربلاء', 'Karbala', 'KRB', 32.6167, 44.0333),
  (uuid_generate_v4(), 'واسط', 'Wasit', 'WST', 32.4500, 45.8333),
  (uuid_generate_v4(), 'المثنى', 'Muthanna', 'MTH', 30.5000, 45.5000),
  (uuid_generate_v4(), 'القادسية', 'Qadisiyyah', 'QDS', 31.9833, 45.0500),
  (uuid_generate_v4(), 'ميسان', 'Maysan', 'MYS', 31.8333, 47.1500),
  (uuid_generate_v4(), 'دهوك', 'Duhok', 'DHK', 36.8667, 43.0000),
  (uuid_generate_v4(), 'السليمانية', 'Sulaymaniyah', 'SLY', 35.5500, 45.4333),
  (uuid_generate_v4(), 'حلبجة', 'Halabja', 'HLB', 35.1833, 45.9833)
ON CONFLICT (code) DO NOTHING;

-- Districts — Baghdad
INSERT INTO districts (id, governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT uuid_generate_v4(), g.id, d.name_ar, d.name_en, d.code, d.lat, d.lng
FROM governorates g
CROSS JOIN (VALUES
  ('الكرخ', 'Karkh', 'KRK-BGD', 33.3000, 44.3300),
  ('الرصافة', 'Rusafa', 'RSF-BGD', 33.3300, 44.4000),
  ('الصدر', 'Sadr City', 'SDR-BGD', 33.3833, 44.4667),
  ('أبو غريب', 'Abu Ghraib', 'AGB-BGD', 33.2833, 44.1833),
  ('المحمودية', 'Mahmudiya', 'MHM-BGD', 33.0667, 44.3667)
) AS d(name_ar, name_en, code, lat, lng)
WHERE g.code = 'BGD'
ON CONFLICT (code) DO NOTHING;

-- Districts — Basra
INSERT INTO districts (id, governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT uuid_generate_v4(), g.id, d.name_ar, d.name_en, d.code, d.lat, d.lng
FROM governorates g
CROSS JOIN (VALUES
  ('البصرة المركز', 'Basra Center', 'CTR-BSR', 30.5085, 47.7804),
  ('الزبير', 'Zubayr', 'ZBR-BSR', 30.3833, 47.7000),
  ('القرنة', 'Qurna', 'QRN-BSR', 31.0167, 47.4333),
  ('أبو الخصيب', 'Abu Al-Khaseeb', 'AKS-BSR', 30.0500, 48.0167)
) AS d(name_ar, name_en, code, lat, lng)
WHERE g.code = 'BSR'
ON CONFLICT (code) DO NOTHING;

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 10: SEED DATA — Sample Form                        ║
-- ╚═══════════════════════════════════════════════════════════╝

INSERT INTO forms (
  title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps
) VALUES (
  'نموذج فحص مراكز التطعيم',
  'Vaccination Center Inspection Form',
  'نموذج لفحص ومتابعة مراكز التطعيم في الميدان',
  'Form for field inspection of vaccination centers',
  '{
    "fields": [
      {"key": "center_name", "type": "text", "label_ar": "اسم المركز", "required": true},
      {"key": "center_type", "type": "select", "label_ar": "نوع المركز", "options": ["رئيسي", "فرعي", "متنقل"], "required": true},
      {"key": "staff_count", "type": "number", "label_ar": "عدد الموظفين", "required": true},
      {"key": "vaccines_available", "type": "multiselect", "label_ar": "اللقاحات المتوفرة", "options": ["BCG", "OPV", "DPT", "Hepatitis B", "Measles", "MMR"]},
      {"key": "cold_chain_status", "type": "select", "label_ar": "حالة سلسلة التبريد", "options": ["ممتاز", "جيد", "يحتاج صيانة", "معطل"], "required": true},
      {"key": "notes", "type": "textarea", "label_ar": "ملاحظات"}
    ]
  }'::jsonb,
  true,
  true
);

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 11: SIA Forms                                      ║
-- ╚═══════════════════════════════════════════════════════════╝

DELETE FROM forms WHERE title_ar IN (
  'استمارة الاشراف للنشاط الايصالي التكاملي',
  'استمارة الجاهزية للنشاط الايصالي التكاملي'
) AND deleted_at IS NULL;

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
      {"id": "general_info", "title_ar": "المعلومات العامة", "order": 1, "fields": [
        {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
        {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
        {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
        {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
        {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
        {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
        {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
        {"key": "district_id", "type": "district", "label_ar": "المديرية", "required": true},
        {"key": "health_facility", "type": "text", "label_ar": "المرفق الصحي التابع للفريق", "required": true},
        {"key": "village_name", "type": "text", "label_ar": "اسم القرية التي يعمل بها الفريق", "required": true},
        {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
        {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true},
        {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true}
      ]},
      {"id": "team_info", "title_ar": "معلومات الفريق", "order": 2, "fields": [
        {"key": "team_members", "type": "textarea", "label_ar": "أسماء أعضاء الفريق", "required": true},
        {"key": "has_activity_plan", "type": "yesno", "label_ar": "هل لدى الفريق خطة وخارطة تبين القرى المستهدفة؟", "required": true},
        {"key": "active_members_count", "type": "number", "label_ar": "أعضاء الفريق العاملين", "required": true},
        {"key": "has_doctor_or_trained", "type": "yesno", "label_ar": "هل أحد أعضاء الفريق طبيب أو فني مدرب؟", "required": true},
        {"key": "wearing_uniform", "type": "yesno", "label_ar": "هل يلتزم أعضاء الفريق بلبس الزي (البالطو)؟", "required": true}
      ]},
      {"id": "work_environment", "title_ar": "بيئة العمل والتنسيق", "order": 3, "fields": [
        {"key": "suitable_location", "type": "yesno", "label_ar": "هل المكان المختار مناسب ويضمن الخصوصية؟", "required": true},
        {"key": "community_coordination", "type": "yesno", "label_ar": "هل تم التنسيق المسبق مع المجتمع؟", "required": true},
        {"key": "has_speaker", "type": "yesno", "label_ar": "هل يتوفر مع الفريق مكبر صوت؟", "required": true},
        {"key": "has_transport", "type": "yesno", "label_ar": "هل توجد وسيلة نقل مناسبة؟", "required": true},
        {"key": "previous_visit", "type": "yesno", "label_ar": "هل تمت زيارة الفريق من قبل المستوى الأعلى؟", "required": true}
      ]},
      {"id": "records", "title_ar": "السجلات والوثائق", "order": 4, "fields": [
        {"key": "complete_records", "type": "yesno", "label_ar": "هل تتوفر سجلات مكتملة؟", "required": true},
        {"key": "daily_work_forms", "type": "yesno", "label_ar": "هل توجد استمارات العمل اليومي؟", "required": true},
        {"key": "correct_data_entry", "type": "yesno", "label_ar": "هل يتم تدوين البيانات بشكل صحيح؟", "required": true},
        {"key": "next_visit_noted", "type": "yesno", "label_ar": "هل يتم تدوين العودة للزيارة القادمة؟", "required": true}
      ]},
      {"id": "service_quality", "title_ar": "جودة الخدمة", "order": 5, "fields": [
        {"key": "good_acceptance", "type": "yesno", "label_ar": "هل يوجد إقبال جيد على الخدمة؟", "required": true},
        {"key": "safe_vaccination", "type": "yesno", "label_ar": "هل يتم ممارسة التطعيم الآمن؟", "required": true},
        {"key": "muac_measurement", "type": "yesno", "label_ar": "هل يتم قياس محيط منتصف الذراع؟", "required": true}
      ]},
      {"id": "follow_up", "title_ar": "المتابعة والتوصيات", "order": 6, "fields": [
        {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
        {"key": "actions_taken", "type": "textarea", "label_ar": "الإجراءات المتخذة", "required": true},
        {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
        {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
      ]}
    ]
  }'::jsonb,
  true, true, true, 5
);

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
      {"id": "general_info", "title_ar": "المعلومات العامة", "order": 1, "fields": [
        {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
        {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
        {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
        {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
      ]},
      {"id": "readiness", "title_ar": "قائمة تقييم الجاهزية", "order": 2, "fields": [
        {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية؟", "required": true},
        {"key": "routine_vaccines_available", "type": "yesno", "label_ar": "توفر اللقاحات الروتينية", "required": true},
        {"key": "staff_available", "type": "yesno", "label_ar": "توفر الكادر الصحي", "required": true},
        {"key": "preparatory_meeting_held", "type": "yesno", "label_ar": "هل تم الاجتماع التحضيري؟", "required": true}
      ]},
      {"id": "launch", "title_ar": "حالة التدشين", "order": 3, "fields": [
        {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة جاهزة للتدشين؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true},
        {"key": "postponement_reasons", "type": "textarea", "label_ar": "أسباب التأجيل"}
      ]},
      {"id": "notes", "title_ar": "ملاحظات", "order": 4, "fields": [
        {"key": "notes", "type": "textarea", "label_ar": "ملاحظات"},
        {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
      ]}
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 12: Polio Campaign Forms                           ║
-- ╚═══════════════════════════════════════════════════════════╝

DELETE FROM forms WHERE title_ar IN (
  'استمارة جاهزية حملة شلل الأطفال',
  'استمارة الاشراف لحملة شلل الأطفال',
  'استمارة المسح العشوائي لحملة شلل الأطفال'
) AND deleted_at IS NULL;

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة جاهزية حملة شلل الأطفال',
  'Polio Campaign Readiness Form',
  'استمارة تقييم جاهزية المحافظة لتنفيذ حملة شلل الأطفال',
  'Form for assessing governorate readiness for polio campaign',
  '{
    "sections": [
      {"id": "general", "title_ar": "المعلومات العامة", "order": 1, "fields": [
        {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
        {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
        {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
      ]},
      {"id": "budget", "title_ar": "الميزانية والمستلزمات", "order": 2, "fields": [
        {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية؟", "required": true},
        {"key": "vaccines_distributed", "type": "yesno", "label_ar": "هل تم إمداد اللقاحات؟", "required": true}
      ]},
      {"id": "training", "title_ar": "التدريب", "order": 3, "fields": [
        {"key": "training_started", "type": "yesno", "label_ar": "هل تم البدء بالتدريب؟", "required": true},
        {"key": "training_quality", "type": "select", "label_ar": "جودة التدريب", "options": ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"]}
      ]},
      {"id": "launch", "title_ar": "حالة التدشين", "order": 4, "fields": [
        {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة جاهزة؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true}
      ]}
    ]
  }'::jsonb,
  true, true, false, 0
);

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
      {"id": "general", "title_ar": "المعلومات العامة", "order": 1, "fields": [
        {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
        {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
        {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
        {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true},
        {"key": "district_id", "type": "district", "label_ar": "المديرية", "required": true},
        {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
        {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true}
      ]},
      {"id": "vaccination", "title_ar": "ممارسة التطعيم", "order": 2, "fields": [
        {"key": "asks_all_under5", "type": "yesno", "label_ar": "هل يسأل الفريق على جميع الأطفال دون الخامسة؟", "required": true},
        {"key": "correct_drops_45deg", "type": "yesno", "label_ar": "هل يتم إعطاء قطرتين بزاوية 45 درجة؟", "required": true},
        {"key": "marks_fingers_correctly", "type": "yesno", "label_ar": "هل يتم تعليم أصابع الأطفال؟", "required": true}
      ]},
      {"id": "supplies", "title_ar": "المستلزمات", "order": 3, "fields": [
        {"key": "sufficient_vials", "type": "yesno", "label_ar": "هل يوجد كمية كافية من اللقاح؟", "required": true},
        {"key": "proper_cold_chain", "type": "yesno", "label_ar": "هل اللقاحات محفوظة بشكل سليم؟", "required": true}
      ]},
      {"id": "challenges", "title_ar": "التحديات", "order": 4, "fields": [
        {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
        {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
        {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
      ]}
    ]
  }'::jsonb,
  true, true, true, 5
);

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  uuid_generate_v4(),
  'استمارة المسح العشوائي لحملة شلل الأطفال',
  'Polio Campaign Random Survey Form',
  'استمارة لإجراء مسح عشوائي لتقييم تغطية التطعيم',
  'Form for random survey to assess vaccination coverage during polio campaign',
  '{
    "sections": [
      {"id": "general", "title_ar": "المعلومات العامة", "order": 1, "fields": [
        {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
        {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
        {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
        {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true},
        {"key": "district_id", "type": "district", "label_ar": "المديرية", "required": true},
        {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true}
      ]},
      {"id": "household", "title_ar": "بيانات المنزل", "order": 2, "fields": [
        {"key": "house_number", "type": "text", "label_ar": "رقم المنزل", "required": true},
        {"key": "house_owner_name", "type": "text", "label_ar": "اسم صاحب المنزل", "required": true}
      ]},
      {"id": "under5", "title_ar": "أطفال دون الخامسة", "order": 3, "fields": [
        {"key": "total_under5", "type": "number", "label_ar": "إجمالي الأطفال دون الخامسة", "required": true},
        {"key": "vaccinated_under5", "type": "number", "label_ar": "عدد المطعمين", "required": true},
        {"key": "unvaccinated_under5", "type": "number", "label_ar": "عدد غير المطعمين", "required": true}
      ]},
      {"id": "reasons", "title_ar": "أسباب عدم التطعيم", "order": 4, "fields": [
        {"key": "refusal_reasons", "type": "textarea", "label_ar": "أسباب الرفض"}
      ]},
      {"id": "signature", "title_ar": "التوقيع", "order": 5, "fields": [
        {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
      ]}
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 13: Yemen Governorates & Districts                 ║
-- ╚═══════════════════════════════════════════════════════════╝

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

-- Yemen Districts (sample - Abyan, Aden)
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

-- Note: Full Yemen districts and health facilities from 005_yemen_facilities.sql
-- can be added separately after this combined migration succeeds.
-- The 005 file contains 100+ districts and 800+ health facilities.

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  PART 14: COMMENTS                                       ║
-- ╚═══════════════════════════════════════════════════════════╝

COMMENT ON TABLE governorates IS 'Administrative governorate divisions (محافظات)';
COMMENT ON TABLE districts IS 'Administrative district divisions (مديريات)';
COMMENT ON TABLE profiles IS 'User profiles with role-based access control';
COMMENT ON TABLE forms IS 'Dynamic form definitions with JSON schema';
COMMENT ON TABLE form_submissions IS 'Form submission data with offline sync support';
COMMENT ON TABLE supply_shortages IS 'Supply shortage tracking with geo-location';
COMMENT ON TABLE audit_logs IS 'Immutable audit trail for all system actions';
COMMENT ON TABLE health_facilities IS 'Health facilities (المرافق الصحية)';

COMMIT;

-- ============================================================
-- ✅ DONE! If you see "COMMIT" without errors, the migration succeeded.
-- ============================================================
-- Next steps:
-- 1. Run the full 005_yemen_facilities.sql separately for all Yemen districts/facilities
-- 2. Create your first admin user in Supabase Auth
-- 3. The handle_new_user trigger will auto-create their profile
-- ============================================================
