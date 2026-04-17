-- ============================================================
-- Dry EPI Store — Database Schema v1.0
-- إدارة المخازن الجافة للبرنامج الوطني للتحصين الصحي الموسع
-- ============================================================

BEGIN;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- 2. ENUMS
-- ============================================================
DO $$ BEGIN CREATE TYPE user_role AS ENUM ('admin','central','warehouse_manager','store_keeper','data_entry');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE movement_type AS ENUM ('receipt','issue','transfer_out','transfer_in','adjustment','return','damage','expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE movement_status AS ENUM ('pending','approved','completed','cancelled','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE alert_type AS ENUM ('low_stock','expiry_warning','expired','overstock','transfer_pending');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE alert_severity AS ENUM ('critical','high','medium','low','info');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE audit_action AS ENUM ('create','read','update','delete','login','logout','approve','reject','transfer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 3. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS governorates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
  center_lat DOUBLE PRECISION, center_lng DOUBLE PRECISION,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate_id UUID NOT NULL REFERENCES governorates(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
  center_lat DOUBLE PRECISION, center_lng DOUBLE PRECISION,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'data_entry',
  governorate_id UUID REFERENCES governorates(id),
  district_id UUID REFERENCES districts(id),
  warehouse_id UUID,
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

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

ALTER TABLE profiles ADD CONSTRAINT profiles_warehouse_fk
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL;

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

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  action audit_action NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  device_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  label_ar TEXT,
  type TEXT DEFAULT 'string',
  category TEXT DEFAULT 'general',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  category TEXT DEFAULT 'general',
  data JSONB DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Chat messages (keep from EPI Supervisor)
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_user BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_warehouse ON profiles(warehouse_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_warehouses_gov ON warehouses(governorate_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_warehouses_district ON warehouses(district_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_code ON items(code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_vaccine ON items(is_vaccine) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_warehouse ON stock_levels(warehouse_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_item ON stock_levels(item_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stock_expiry ON stock_levels(expiry_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_type ON stock_movements(movement_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_status ON stock_movements(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_item ON stock_movements(item_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_movements_date ON stock_movements(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_unread ON alerts(is_read, created_at DESC) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, is_read, created_at DESC);

-- ============================================================
-- 5. FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.user_role()
RETURNS user_role LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM profiles WHERE id = auth.uid() LIMIT 1; $$;

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
        VALUES ('expired', 'critical', 'منتج منتهي الصلاحية',
          'الدفعة ' || COALESCE(NEW.batch_number, 'غير معروف') || ' انتهت صلاحيتها',
          COALESCE(NEW.destination_warehouse_id, NEW.source_warehouse_id), NEW.item_id, NEW.quantity)
        ON CONFLICT DO NOTHING;
      ELSIF v_expiry_days <= 90 THEN
        INSERT INTO alerts (alert_type, severity, title, message, warehouse_id, item_id, quantity)
        VALUES ('expiry_warning', CASE WHEN v_expiry_days <= 30 THEN 'high'::alert_severity ELSE 'medium'::alert_severity END,
          'اقتراب انتهاء الصلاحية',
          'الدفعة ' || COALESCE(NEW.batch_number, 'غير معروف') || ' ستنتهي خلال ' || v_expiry_days || ' يوم',
          COALESCE(NEW.destination_warehouse_id, NEW.source_warehouse_id), NEW.item_id, NEW.quantity)
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END; $$;

-- ============================================================
-- 6. TRIGGER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_audit_log() RETURNS TRIGGER AS $$
DECLARE old_json JSONB; new_json JSONB;
BEGIN
  IF TG_OP = 'DELETE' THEN old_json = to_jsonb(OLD);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data)
    VALUES (auth.uid(), 'delete', TG_TABLE_NAME, OLD.id, old_json); RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN old_json = to_jsonb(OLD); new_json = to_jsonb(NEW);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data, new_data)
    VALUES (auth.uid(), 'update', TG_TABLE_NAME, NEW.id, old_json, new_json); RETURN NEW;
  ELSIF TG_OP = 'INSERT' THEN new_json = to_jsonb(NEW);
    INSERT INTO audit_logs (user_id, action, table_name, record_id, new_data)
    VALUES (auth.uid(), 'create', TG_TABLE_NAME, NEW.id, new_json); RETURN NEW;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'data_entry'));
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END; $$;

-- ============================================================
-- 7. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "profiles_insert_self" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_insert_admin" ON profiles FOR INSERT WITH CHECK (public.user_role() = 'admin');
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (public.user_role() IN ('admin','central'));
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (public.user_role() = 'admin');
CREATE POLICY "profiles_delete_admin" ON profiles FOR DELETE USING (public.user_role() = 'admin');

-- GOVERNORATES & DISTRICTS
CREATE POLICY "gov_select_all" ON governorates FOR SELECT USING (true);
CREATE POLICY "gov_modify_admin" ON governorates FOR ALL USING (public.user_role() = 'admin');
CREATE POLICY "dist_select_all" ON districts FOR SELECT USING (true);
CREATE POLICY "dist_modify_admin" ON districts FOR ALL USING (public.user_role() = 'admin');

-- WAREHOUSES
CREATE POLICY "wh_select_all" ON warehouses FOR SELECT USING (is_active = true AND deleted_at IS NULL);
CREATE POLICY "wh_select_admin" ON warehouses FOR SELECT USING (public.user_role() = 'admin');
CREATE POLICY "wh_modify_admin" ON warehouses FOR ALL USING (public.user_role() IN ('admin','central'));

-- ITEM CATEGORIES
CREATE POLICY "cat_select_all" ON item_categories FOR SELECT USING (true);
CREATE POLICY "cat_modify_admin" ON item_categories FOR ALL USING (public.user_role() IN ('admin','central'));

-- ITEMS
CREATE POLICY "items_select_all" ON items FOR SELECT USING (is_active = true AND deleted_at IS NULL);
CREATE POLICY "items_modify_admin" ON items FOR ALL USING (public.user_role() IN ('admin','central'));

-- STOCK LEVELS
CREATE POLICY "stock_select" ON stock_levels FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true
    WHEN 'central' THEN true
    ELSE warehouse_id = public.user_warehouse_id()
  END
);
CREATE POLICY "stock_modify" ON stock_levels FOR ALL USING (
  public.user_role() IN ('admin','central') OR warehouse_id = public.user_warehouse_id()
);

-- STOCK MOVEMENTS
CREATE POLICY "mov_insert" ON stock_movements FOR INSERT WITH CHECK (requested_by = auth.uid());
CREATE POLICY "mov_select" ON stock_movements FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true
    WHEN 'central' THEN true
    ELSE source_warehouse_id = public.user_warehouse_id()
      OR destination_warehouse_id = public.user_warehouse_id()
      OR requested_by = auth.uid()
  END
);
CREATE POLICY "mov_update" ON stock_movements FOR UPDATE USING (
  requested_by = auth.uid() OR public.user_role() IN ('admin','central','warehouse_manager')
);

-- ALERTS
CREATE POLICY "alerts_select" ON alerts FOR SELECT USING (
  CASE public.user_role()
    WHEN 'admin' THEN true
    WHEN 'central' THEN true
    ELSE warehouse_id = public.user_warehouse_id()
  END
);
CREATE POLICY "alerts_update" ON alerts FOR UPDATE USING (
  public.user_role() IN ('admin','central') OR warehouse_id = public.user_warehouse_id()
);

-- AUDIT LOGS
CREATE POLICY "audit_select_admin" ON audit_logs FOR SELECT USING (public.user_role() IN ('admin','central'));
CREATE POLICY "audit_insert_system" ON audit_logs FOR INSERT WITH CHECK (true);

-- APP SETTINGS
CREATE POLICY "settings_select_auth" ON app_settings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "settings_manage_admin" ON app_settings FOR ALL USING (public.user_role() = 'admin');

-- NOTIFICATIONS
CREATE POLICY "notif_select_own" ON notifications FOR SELECT USING (recipient_id = auth.uid());
CREATE POLICY "notif_update_own" ON notifications FOR UPDATE USING (recipient_id = auth.uid());
CREATE POLICY "notif_insert_system" ON notifications FOR INSERT WITH CHECK (true);

-- CHAT
CREATE POLICY "chat_select_own" ON chat_messages FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "chat_insert_own" ON chat_messages FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "chat_select_admin" ON chat_messages FOR SELECT USING (public.user_role() IN ('admin','central'));

-- ============================================================
-- 8. TRIGGERS
-- ============================================================

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_warehouses_updated BEFORE UPDATE ON warehouses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_items_updated BEFORE UPDATE ON items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_stock_updated BEFORE UPDATE ON stock_levels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_movements_updated BEFORE UPDATE ON stock_movements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_profiles_audit AFTER INSERT OR UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_warehouses_audit AFTER INSERT OR UPDATE OR DELETE ON warehouses FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_items_audit AFTER INSERT OR UPDATE OR DELETE ON items FOR EACH ROW EXECUTE FUNCTION create_audit_log();
CREATE TRIGGER trg_movements_audit AFTER INSERT OR UPDATE OR DELETE ON stock_movements FOR EACH ROW EXECUTE FUNCTION create_audit_log();

CREATE TRIGGER trg_auth_signup AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 9. GRANTS
-- ============================================================
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT SELECT ON governorates TO authenticated;
GRANT SELECT ON districts TO authenticated;
GRANT SELECT, UPDATE ON profiles TO authenticated;
GRANT SELECT ON warehouses TO authenticated;
GRANT SELECT ON item_categories TO authenticated;
GRANT SELECT ON items TO authenticated;
GRANT SELECT, INSERT, UPDATE ON stock_levels TO authenticated;
GRANT SELECT, INSERT, UPDATE ON stock_movements TO authenticated;
GRANT SELECT, UPDATE ON alerts TO authenticated;
GRANT SELECT ON audit_logs TO authenticated;
GRANT SELECT ON app_settings TO authenticated;
GRANT SELECT ON notifications TO authenticated;
GRANT SELECT, INSERT ON chat_messages TO authenticated;
GRANT INSERT ON profiles TO anon;

-- ============================================================
-- 10. SEED DATA
-- ============================================================

INSERT INTO governorates (name_ar, name_en, code, center_lat, center_lng) VALUES
  ('صنعاء', 'Sanaa', 'SAN', 15.3694, 44.1910),
  ('عدن', 'Aden', 'ADE', 12.7855, 45.0187),
  ('تعز', 'Taiz', 'TAZ', 13.5790, 44.0210),
  ('الحديدة', 'Hodeidah', 'HOD', 14.7978, 42.9545),
  ('إب', 'Ibb', 'IBB', 13.9667, 44.1833),
  ('ذمار', 'Dhamar', 'DHA', 14.5583, 44.4014),
  ('حضرموت', 'Hadhramaut', 'HAD', 15.9600, 48.7900),
  ('لحج', 'Lahij', 'LAH', 13.0567, 44.8819),
  ('أبين', 'Abyan', 'ABY', 13.6300, 45.3800),
  ('البيضاء', 'Al Bayda', 'BAY', 14.3542, 45.0186),
  ('مأرب', 'Marib', 'MRB', 15.4690, 45.3253),
  ('الجوف', 'Al Jawf', 'JWF', 16.7833, 45.5833),
  ('صعدة', 'Saada', 'SAD', 16.9400, 43.7600),
  ('عمران', 'Amran', 'AMR', 15.6594, 43.9439),
  ('المحويت', 'Al Mahwit', 'MHW', 15.4711, 43.5464),
  ('ريمة', 'Raymah', 'RYM', 14.6278, 43.7167),
  ('شبوة', 'Shabwah', 'SHB', 14.3400, 46.8300),
  ('المهرة', 'Al Mahrah', 'MAH', 16.5300, 51.7600),
  ('سقطرى', 'Socotra', 'SOC', 12.4600, 53.8200),
  ('الضالع', 'Al Dhale', 'DLH', 13.6950, 44.7300),
  ('حجة', 'Hajjah', 'HAJ', 15.6917, 43.6028),
  ('أمانة العاصمة', 'Capital Secretariat', 'CAP', 15.3547, 44.2066)
ON CONFLICT (code) DO NOTHING;

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
