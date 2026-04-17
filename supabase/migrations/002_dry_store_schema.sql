-- ============================================================
-- Dry EPI Store — Database Schema v1.0
-- Handles existing tables gracefully
-- ============================================================

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Drop old schema if exists
DROP TABLE IF EXISTS form_submissions CASCADE;
DROP TABLE IF EXISTS forms CASCADE;
DROP TABLE IF EXISTS shortages CASCADE;
DROP TABLE IF EXISTS pages CASCADE;
DROP TABLE IF EXISTS rate_limits CASCADE;
DROP TYPE IF EXISTS submission_status CASCADE;
DROP TYPE IF EXISTS shortage_severity CASCADE;
DROP TYPE IF EXISTS campaign_type CASCADE;

-- Update user_role enum if it has old values
DO $$ BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'warehouse_manager';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'store_keeper';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Create new enums
DO $$ BEGIN CREATE TYPE movement_type AS ENUM ('receipt','issue','transfer_out','transfer_in','adjustment','return','damage','expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE movement_status AS ENUM ('pending','approved','completed','cancelled','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE alert_type AS ENUM ('low_stock','expiry_warning','expired','overstock','transfer_pending');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE alert_severity AS ENUM ('critical','high','medium','low','info');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Update audit_action enum
DO $$ BEGIN CREATE TYPE audit_action AS ENUM ('create','read','update','delete','login','logout','approve','reject','transfer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Warehouses
CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  warehouse_type TEXT NOT NULL DEFAULT 'dry',
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  address TEXT,
  capacity_sqm NUMERIC,
  manager_id UUID REFERENCES profiles(id),
  center_lat DOUBLE PRECISION, center_lng DOUBLE PRECISION,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Add warehouse_id to profiles if not exists
DO $$ BEGIN
  ALTER TABLE profiles ADD COLUMN warehouse_id UUID REFERENCES warehouses(id);
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Item categories
CREATE TABLE IF NOT EXISTS item_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Items
CREATE TABLE IF NOT EXISTS items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  category_id UUID REFERENCES item_categories(id),
  unit TEXT NOT NULL DEFAULT 'unit',
  description TEXT,
  min_stock_level INTEGER DEFAULT 10,
  max_stock_level INTEGER DEFAULT 1000,
  requires_expiry BOOLEAN NOT NULL DEFAULT true,
  requires_batch BOOLEAN NOT NULL DEFAULT true,
  is_vaccine BOOLEAN NOT NULL DEFAULT false,
  storage_temp_min NUMERIC,
  storage_temp_max NUMERIC,
  qr_code TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Stock levels
CREATE TABLE IF NOT EXISTS stock_levels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL DEFAULT 0,
  batch_number TEXT,
  expiry_date DATE,
  manufacturing_date DATE,
  supplier TEXT,
  notes TEXT,
  qr_code TEXT,
  last_counted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT stock_levels_quantity_check CHECK (quantity >= 0),
  CONSTRAINT stock_levels_unique_batch UNIQUE (warehouse_id, item_id, batch_number)
);

-- Stock movements
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  movement_number TEXT NOT NULL UNIQUE,
  movement_type movement_type NOT NULL,
  status movement_status NOT NULL DEFAULT 'pending',
  source_warehouse_id UUID REFERENCES warehouses(id),
  destination_warehouse_id UUID REFERENCES warehouses(id),
  item_id UUID NOT NULL REFERENCES items(id),
  quantity INTEGER NOT NULL,
  batch_number TEXT,
  expiry_date DATE,
  unit_cost NUMERIC DEFAULT 0,
  total_cost NUMERIC DEFAULT 0,
  reference_number TEXT,
  notes TEXT,
  requested_by UUID NOT NULL REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  device_id TEXT,
  offline_id TEXT,
  qr_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT stock_movements_quantity_check CHECK (quantity > 0)
);

-- Alerts
CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type alert_type NOT NULL,
  severity alert_severity NOT NULL DEFAULT 'medium',
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  warehouse_id UUID REFERENCES warehouses(id),
  item_id UUID REFERENCES items(id),
  movement_id UUID REFERENCES stock_movements(id),
  quantity INTEGER,
  threshold_value INTEGER,
  is_read BOOLEAN NOT NULL DEFAULT false,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Chat messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_user BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_warehouses_gov ON warehouses(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_code ON items(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_warehouse ON stock_levels(warehouse_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_item ON stock_levels(item_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_expiry ON stock_levels(expiry_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_type ON stock_movements(movement_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_status ON stock_movements(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_item ON stock_movements(item_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_date ON stock_movements(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_unread ON alerts(is_read, created_at DESC) WHERE is_read = false;

-- Functions
CREATE OR REPLACE FUNCTION public.user_warehouse_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT warehouse_id FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

CREATE OR REPLACE FUNCTION generate_movement_number()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_count INTEGER; v_year TEXT;
BEGIN
  v_year := to_char(now(), 'YY');
  SELECT COUNT(*) + 1 INTO v_count FROM stock_movements WHERE created_at >= date_trunc('year', now());
  RETURN 'MOV-' || v_year || '-' || LPAD(v_count::TEXT, 6, '0');
END; $$;

CREATE OR REPLACE FUNCTION check_stock_alerts()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_min_level INTEGER; v_current_qty INTEGER; v_expiry_days INTEGER;
BEGIN
  SELECT min_stock_level INTO v_min_level FROM items WHERE id = NEW.item_id;
  IF NEW.status = 'completed' THEN
    IF NEW.destination_warehouse_id IS NOT NULL THEN
      SELECT COALESCE(SUM(quantity), 0) INTO v_current_qty
      FROM stock_levels WHERE item_id = NEW.item_id AND warehouse_id = NEW.destination_warehouse_id AND deleted_at IS NULL;
      IF v_current_qty <= COALESCE(v_min_level, 10) THEN
        INSERT INTO alerts (alert_type, severity, title, message, warehouse_id, item_id, quantity, threshold_value)
        VALUES ('low_stock', CASE WHEN v_current_qty = 0 THEN 'critical'::alert_severity ELSE 'high'::alert_severity END,
          'نقص في المخزون', 'الكمية الحالية (' || v_current_qty || ') أقل من الحد الأدنى (' || COALESCE(v_min_level, 10) || ')',
          NEW.destination_warehouse_id, NEW.item_id, v_current_qty, COALESCE(v_min_level, 10))
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
    IF NEW.expiry_date IS NOT NULL THEN
      v_expiry_days := NEW.expiry_date - CURRENT_DATE;
      IF v_expiry_days <= 0 THEN
        INSERT INTO alerts (alert_type, severity, title, message, warehouse_id, item_id, quantity)
        VALUES ('expired', 'critical', 'منتج منتهي الصلاحية', 'الدفعة ' || COALESCE(NEW.batch_number, 'غير معروف') || ' انتهت صلاحيتها',
          COALESCE(NEW.destination_warehouse_id, NEW.source_warehouse_id), NEW.item_id, NEW.quantity) ON CONFLICT DO NOTHING;
      ELSIF v_expiry_days <= 90 THEN
        INSERT INTO alerts (alert_type, severity, title, message, warehouse_id, item_id, quantity)
        VALUES ('expiry_warning', CASE WHEN v_expiry_days <= 30 THEN 'high'::alert_severity ELSE 'medium'::alert_severity END,
          'اقتراب انتهاء الصلاحية', 'الدفعة ' || COALESCE(NEW.batch_number, 'غير معروف') || ' ستنتهي خلال ' || v_expiry_days || ' يوم',
          COALESCE(NEW.destination_warehouse_id, NEW.source_warehouse_id), NEW.item_id, NEW.quantity) ON CONFLICT DO NOTHING;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END; $$;

-- RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN CREATE POLICY "wh_select_all" ON warehouses FOR SELECT USING (is_active = true AND deleted_at IS NULL); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "wh_modify_admin" ON warehouses FOR ALL USING (public.user_role() IN ('admin','central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "cat_select_all" ON item_categories FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "cat_modify_admin" ON item_categories FOR ALL USING (public.user_role() IN ('admin','central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "items_select_all" ON items FOR SELECT USING (is_active = true AND deleted_at IS NULL); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "items_modify_admin" ON items FOR ALL USING (public.user_role() IN ('admin','central')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "stock_select" ON stock_levels FOR SELECT USING (CASE public.user_role() WHEN 'admin' THEN true WHEN 'central' THEN true ELSE warehouse_id = public.user_warehouse_id() END); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "stock_modify" ON stock_levels FOR ALL USING (public.user_role() IN ('admin','central') OR warehouse_id = public.user_warehouse_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "mov_insert" ON stock_movements FOR INSERT WITH CHECK (requested_by = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "mov_select" ON stock_movements FOR SELECT USING (CASE public.user_role() WHEN 'admin' THEN true WHEN 'central' THEN true ELSE source_warehouse_id = public.user_warehouse_id() OR destination_warehouse_id = public.user_warehouse_id() OR requested_by = auth.uid() END); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "mov_update" ON stock_movements FOR UPDATE USING (requested_by = auth.uid() OR public.user_role() IN ('admin','central','warehouse_manager')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "alerts_select" ON alerts FOR SELECT USING (CASE public.user_role() WHEN 'admin' THEN true WHEN 'central' THEN true ELSE warehouse_id = public.user_warehouse_id() END); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "alerts_update" ON alerts FOR UPDATE USING (public.user_role() IN ('admin','central') OR warehouse_id = public.user_warehouse_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "chat_select_own" ON chat_messages FOR SELECT USING (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "chat_insert_own" ON chat_messages FOR INSERT WITH CHECK (user_id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Triggers
DO $$ BEGIN CREATE TRIGGER trg_warehouses_updated BEFORE UPDATE ON warehouses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_items_updated BEFORE UPDATE ON items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_stock_updated BEFORE UPDATE ON stock_levels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_movements_updated BEFORE UPDATE ON stock_movements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_warehouses_audit AFTER INSERT OR UPDATE OR DELETE ON warehouses FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_items_audit AFTER INSERT OR UPDATE OR DELETE ON items FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TRIGGER trg_movements_audit AFTER INSERT OR UPDATE OR DELETE ON stock_movements FOR EACH ROW EXECUTE FUNCTION create_audit_log(); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Grants
GRANT ALL ON warehouses TO service_role;
GRANT ALL ON item_categories TO service_role;
GRANT ALL ON items TO service_role;
GRANT ALL ON stock_levels TO service_role;
GRANT ALL ON stock_movements TO service_role;
GRANT ALL ON alerts TO service_role;
GRANT ALL ON chat_messages TO service_role;
GRANT SELECT ON warehouses TO authenticated;
GRANT SELECT ON item_categories TO authenticated;
GRANT SELECT ON items TO authenticated;
GRANT SELECT, INSERT, UPDATE ON stock_levels TO authenticated;
GRANT SELECT, INSERT, UPDATE ON stock_movements TO authenticated;
GRANT SELECT, UPDATE ON alerts TO authenticated;
GRANT SELECT, INSERT ON chat_messages TO authenticated;

-- Seed data
INSERT INTO item_categories (name_ar, name_en, code) VALUES
  ('لقاحات', 'Vaccines', 'VAC'),
  ('محاقن', 'Syringes', 'SYR'),
  ('صناديق حفظ بارد', 'Cold Boxes', 'CBOX'),
  ('أجهزة قياس', 'Monitoring Equipment', 'MON'),
  ('مستلزمات عامة', 'General Supplies', 'GEN'),
  ('مواد تعقيم', 'Disinfection Materials', 'DIS'),
  ('أدوات حماية', 'PPE', 'PPE'),
  ('وثائق ونماذج', 'Forms & Documents', 'DOC')
ON CONFLICT (code) DO NOTHING;

INSERT INTO app_settings (key, value, label_ar, type, category) VALUES
  ('app_name_ar', '"مخزن EPI الجاف"', 'اسم التطبيق', 'string', 'branding'),
  ('primary_color', '"#0D7C66"', 'اللون الرئيسي', 'color', 'branding'),
  ('low_stock_threshold', '10', 'حد التنبيه للنقص', 'number', 'stock'),
  ('expiry_warning_days', '90', 'تنبيه انتهاء الصلاحية (أيام)', 'number', 'stock'),
  ('critical_expiry_days', '30', 'تحذير انتهاء الصلاحية (أيام)', 'number', 'stock'),
  ('auto_sync_interval', '5', 'فترة المزامنة (دقائق)', 'number', 'sync'),
  ('notification_enabled', 'true', 'تفعيل الإشعارات', 'boolean', 'notifications'),
  ('session_timeout_minutes', '480', 'مهلة الجلسة (دقائق)', 'number', 'security')
ON CONFLICT (key) DO NOTHING;

COMMIT;
