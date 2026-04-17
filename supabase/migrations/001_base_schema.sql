-- ============================================================
-- Dry EPI Store — Base Schema v1
-- Foundation tables, functions, enums, and seed data
-- Must run before 002_dry_store_schema.sql
-- ============================================================

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ═══════════════════════════════════════════════════════════
-- ENUMS
-- ═══════════════════════════════════════════════════════════

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('admin', 'central', 'governorate', 'district', 'data_entry', 'warehouse_manager', 'store_keeper');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════

-- Auto-update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Audit log creator
CREATE OR REPLACE FUNCTION create_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data, new_data)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id::text, OLD.id::text),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Get current user role
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT role::text FROM profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- ═══════════════════════════════════════════════════════════
-- TABLES
-- ═══════════════════════════════════════════════════════════

-- Governorates (22 Yemeni governorates)
CREATE TABLE IF NOT EXISTS governorates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Districts
CREATE TABLE IF NOT EXISTS districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate_id UUID NOT NULL REFERENCES governorates(id),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL,
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  population INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_districts_gov ON districts(governorate_id);

-- Profiles (user accounts)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'data_entry',
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Health facilities
CREATE TABLE IF NOT EXISTS health_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  district_id UUID REFERENCES districts(id),
  facility_type TEXT NOT NULL DEFAULT 'health_center',
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- App settings (key-value store)
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL DEFAULT '{}',
  label_ar TEXT,
  label_en TEXT,
  type TEXT NOT NULL DEFAULT 'string',
  category TEXT NOT NULL DEFAULT 'general',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);

-- Chat messages (admin chat)
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  room TEXT NOT NULL DEFAULT 'general',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_chat_room ON chat_messages(room, created_at DESC);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  category TEXT NOT NULL DEFAULT 'system',
  data JSONB NOT NULL DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notif_recipient ON notifications(recipient_id, is_read, created_at DESC);

-- Notification templates
CREATE TABLE IF NOT EXISTS notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT,
  type TEXT NOT NULL DEFAULT 'info',
  category TEXT NOT NULL DEFAULT 'system',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Campaign types enum
DO $$ BEGIN
  CREATE TYPE campaign_type AS ENUM ('polio_campaign', 'measles_campaign', 'routine_immunization', 'other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Forms
CREATE TABLE IF NOT EXISTS forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  description_ar TEXT,
  description_en TEXT,
  schema JSONB NOT NULL DEFAULT '{}',
  version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  requires_gps BOOLEAN NOT NULL DEFAULT false,
  requires_photo BOOLEAN NOT NULL DEFAULT false,
  max_photos INTEGER NOT NULL DEFAULT 1,
  allowed_roles TEXT[] NOT NULL DEFAULT '{}',
  campaign_type TEXT NOT NULL DEFAULT 'routine_immunization',
  created_by UUID REFERENCES profiles(id),
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Form submissions
DO $$ BEGIN
  CREATE TYPE submission_status AS ENUM ('draft', 'submitted', 'reviewed', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS form_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id UUID NOT NULL REFERENCES forms(id),
  submitted_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  status submission_status NOT NULL DEFAULT 'draft',
  data JSONB NOT NULL DEFAULT '{}',
  gps_lat DOUBLE PRECISION,
  gps_lng DOUBLE PRECISION,
  photos TEXT[] DEFAULT '{}',
  notes TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  submitted_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_submissions_form ON form_submissions(form_id);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON form_submissions(status);
CREATE INDEX IF NOT EXISTS idx_submissions_gov ON form_submissions(governorate_id);
CREATE INDEX IF NOT EXISTS idx_submissions_submitter ON form_submissions(submitted_by);
CREATE INDEX IF NOT EXISTS idx_submissions_created ON form_submissions(created_at DESC);

-- Supply shortages
DO $$ BEGIN
  CREATE TYPE shortage_severity AS ENUM ('critical', 'high', 'medium', 'low');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS supply_shortages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id UUID REFERENCES form_submissions(id),
  reported_by UUID NOT NULL REFERENCES profiles(id),
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  item_name TEXT NOT NULL,
  item_category TEXT,
  quantity_needed INTEGER,
  quantity_available INTEGER NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'unit',
  severity shortage_severity NOT NULL DEFAULT 'medium',
  notes TEXT,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id),
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_shortages_gov ON supply_shortages(governorate_id);
CREATE INDEX IF NOT EXISTS idx_shortages_severity ON supply_shortages(severity);
CREATE INDEX IF NOT EXISTS idx_shortages_unresolved ON supply_shortages(is_resolved) WHERE is_resolved = false;

-- Pages (CMS)
CREATE TABLE IF NOT EXISTS pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  content_ar TEXT,
  content_en TEXT,
  is_published BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- References / Knowledge base
CREATE TABLE IF NOT EXISTS references_kb (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  category TEXT,
  tags TEXT[] DEFAULT '{}',
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Rate limits
CREATE TABLE IF NOT EXISTS rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  endpoint TEXT NOT NULL,
  requests INTEGER NOT NULL DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════
-- RLS
-- ═══════════════════════════════════════════════════════════

ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_shortages ENABLE ROW LEVEL SECURITY;
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_facilities ENABLE ROW LEVEL SECURITY;

-- Governorates: everyone can read
DO $$ BEGIN CREATE POLICY "gov_select" ON governorates FOR SELECT USING (is_active = true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Districts: everyone can read
DO $$ BEGIN CREATE POLICY "dist_select" ON districts FOR SELECT USING (is_active = true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Health facilities: everyone can read
DO $$ BEGIN CREATE POLICY "hf_select" ON health_facilities FOR SELECT USING (is_active = true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Profiles: read all, modify self or admin
DO $$ BEGIN CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_modify_admin" ON profiles FOR UPDATE USING (public.user_role() = 'admin' OR id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- App settings: everyone can read, admin can modify
DO $$ BEGIN CREATE POLICY "settings_select" ON app_settings FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "settings_modify" ON app_settings FOR ALL USING (public.user_role() = 'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Audit logs: admin only
DO $$ BEGIN CREATE POLICY "audit_select" ON audit_logs FOR SELECT USING (public.user_role() IN ('admin', 'central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Chat: authenticated can read/write
DO $$ BEGIN CREATE POLICY "chat_select" ON chat_messages FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "chat_insert" ON chat_messages FOR INSERT WITH CHECK (sender_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Notifications: own or admin
DO $$ BEGIN CREATE POLICY "notif_select" ON notifications FOR SELECT USING (recipient_id = auth.uid() OR public.user_role() = 'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "notif_modify" ON notifications FOR UPDATE USING (recipient_id = auth.uid() OR public.user_role() = 'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Forms: everyone can read active, admin can modify
DO $$ BEGIN CREATE POLICY "forms_select" ON forms FOR SELECT USING (is_active = true AND deleted_at IS NULL); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "forms_modify" ON forms FOR ALL USING (public.user_role() IN ('admin', 'central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Submissions: submitter, admin, or same governorate
DO $$ BEGIN CREATE POLICY "sub_insert" ON form_submissions FOR INSERT WITH CHECK (submitted_by = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "sub_select" ON form_submissions FOR SELECT USING (submitted_by = auth.uid() OR public.user_role() IN ('admin', 'central') OR governorate_id IN (SELECT governorate_id FROM profiles WHERE id = auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "sub_update" ON form_submissions FOR UPDATE USING (submitted_by = auth.uid() OR public.user_role() IN ('admin', 'central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Shortages
DO $$ BEGIN CREATE POLICY "short_select" ON supply_shortages FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "short_insert" ON supply_shortages FOR INSERT WITH CHECK (reported_by = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "short_update" ON supply_shortages FOR UPDATE USING (public.user_role() IN ('admin', 'central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Pages
DO $$ BEGIN CREATE POLICY "pages_select" ON pages FOR SELECT USING (is_published = true OR public.user_role() = 'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "pages_modify" ON pages FOR ALL USING (public.user_role() = 'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════

DO $$ BEGIN CREATE TRIGGER trg_gov_updated BEFORE UPDATE ON governorates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_dist_updated BEFORE UPDATE ON districts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_forms_updated BEFORE UPDATE ON forms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_submissions_updated BEFORE UPDATE ON form_submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_settings_updated BEFORE UPDATE ON app_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Audit triggers
DO $$ BEGIN CREATE TRIGGER trg_profiles_audit AFTER INSERT OR UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_forms_audit AFTER INSERT OR UPDATE OR DELETE ON forms FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_submissions_audit AFTER INSERT OR UPDATE OR DELETE ON form_submissions FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════
-- GRANTS
-- ═══════════════════════════════════════════════════════════

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON governorates TO authenticated;
GRANT SELECT ON districts TO authenticated;
GRANT SELECT ON health_facilities TO authenticated;
GRANT SELECT, UPDATE ON profiles TO authenticated;
GRANT SELECT ON app_settings TO authenticated;
GRANT SELECT ON audit_logs TO authenticated;
GRANT SELECT, INSERT ON chat_messages TO authenticated;
GRANT SELECT, UPDATE ON notifications TO authenticated;
GRANT SELECT ON forms TO authenticated;
GRANT SELECT, INSERT, UPDATE ON form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON supply_shortages TO authenticated;
GRANT SELECT ON pages TO authenticated;

-- ═══════════════════════════════════════════════════════════
-- SEED DATA
-- ═══════════════════════════════════════════════════════════

-- 22 Yemeni Governorates
INSERT INTO governorates (name_ar, name_en, code) VALUES
  ('صنعاء', 'Sanaa', 'SAN'),
  ('عدن', 'Aden', 'ADE'),
  ('تعز', 'Taiz', 'TAZ'),
  ('الحديدة', 'Hodeidah', 'HOD'),
  ('إب', 'Ibb', 'IBB'),
  ('ذمار', 'Dhamar', 'DHA'),
  ('حضرموت', 'Hadhramaut', 'HAD'),
  ('البيضاء', 'Al Bayda', 'BAY'),
  ('لحج', 'Lahij', 'LAH'),
  ('مأرب', 'Marib', 'MAR'),
  ('الجوف', 'Al Jawf', 'JAW'),
  ('صعدة', 'Saada', 'SAD'),
  ('حجة', 'Hajjah', 'HAJ'),
  ('المحويت', 'Al Mahwit', 'MAH'),
  ('ريمة', 'Raymah', 'RAY'),
  ('أمانة العاصمة', 'Amanat Al Asimah', 'AMA'),
  ('شبوة', 'Shabwah', 'SHB'),
  ('أبين', 'Abyan', 'ABY'),
  ('المهرة', 'Al Mahrah', 'MHR'),
  ('سقطرى', 'Socotra', 'SOC'),
  ('عمران', 'Amran', 'AMR'),
  ('الضالع', 'Al Dhale', 'DHA2')
ON CONFLICT (code) DO NOTHING;

-- App settings
INSERT INTO app_settings (key, value, label_ar, label_en, type, category) VALUES
  ('app_name_ar', '"منصة EPI Supervisor''s"', 'اسم التطبيق', 'App Name', 'string', 'branding'),
  ('app_name_en', '"EPI Supervisor Platform"', 'اسم التطبيق بالإنجليزية', 'App Name EN', 'string', 'branding'),
  ('primary_color', '"#0D7C66"', 'اللون الرئيسي', 'Primary Color', 'color', 'branding'),
  ('default_page_size', '20', 'حجم الصفحة الافتراضي', 'Default Page Size', 'number', 'pagination'),
  ('notification_enabled', 'true', 'تفعيل الإشعارات', 'Enable Notifications', 'boolean', 'notifications'),
  ('session_timeout_minutes', '480', 'مهلة الجلسة (دقائق)', 'Session Timeout', 'number', 'security')
ON CONFLICT (key) DO NOTHING;

-- Notification templates
INSERT INTO notification_templates (title, body, type, category) VALUES
  ('تذكير بالإرساليات', 'يرجى إكمال الإرساليات المعلقة قبل نهاية اليوم.', 'warning', 'submission'),
  ('صيانة النظام', 'سيكون النظام في وضع الصيانة.', 'info', 'system'),
  ('نقص في اللقاحات', 'تم رصد نقص في أحد اللقاحات.', 'error', 'shortage'),
  ('إشعار عام', '', 'info', 'system'),
  ('تمت الموافقة', 'تمت الموافقة على طلبك بنجاح.', 'success', 'user');

COMMIT;
