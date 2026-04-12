-- App settings for admin-managed configuration
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  label_ar TEXT,
  type TEXT DEFAULT 'string',  -- string, number, color, boolean
  category TEXT DEFAULT 'general',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default settings
INSERT INTO app_settings (key, value, label_ar, type, category) VALUES
  ('app_name_ar', '"منصة مشرف EPI"', 'اسم التطبيق', 'string', 'branding'),
  ('primary_color', '"#1565C0"', 'اللون الرئيسي', 'color', 'branding'),
  ('offline_days', '30', 'أيام الاحتفاظ المحلي', 'number', 'offline'),
  ('ai_model', '"local"', 'نموذج الذكاء الاصطناعي', 'string', 'ai'),
  ('auto_sync_interval', '5', 'فترة المزامنة التلقائية (دقائق)', 'number', 'sync')
ON CONFLICT (key) DO NOTHING;

-- RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Settings viewable by authenticated" ON app_settings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Settings manageable by admins" ON app_settings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
