-- ═══════════════════════════════════════════════════════════════
--  007: Notifications Enhancements
--  - Add DELETE policy for notifications
--  - Add notification_templates table
--  - Fix grants
-- ═══════════════════════════════════════════════════════════════

-- 1. Delete policy: users can delete their own notifications
DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE USING (recipient_id = auth.uid());

-- Also allow admins to delete any notification
DROP POLICY IF EXISTS "notifications_delete_admin" ON notifications;
CREATE POLICY "notifications_delete_admin" ON notifications
  FOR DELETE USING (public.user_role() IN ('admin', 'central'));

-- Grant DELETE on notifications
GRANT DELETE ON notifications TO authenticated;

-- 2. Notification Templates table
CREATE TABLE IF NOT EXISTS notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'info',
  category TEXT NOT NULL DEFAULT 'system',
  is_system BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for templates
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "templates_select_all" ON notification_templates;
CREATE POLICY "templates_select_all" ON notification_templates
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "templates_insert_admin" ON notification_templates;
CREATE POLICY "templates_insert_admin" ON notification_templates
  FOR INSERT WITH CHECK (public.user_role() IN ('admin', 'central'));

DROP POLICY IF EXISTS "templates_update_admin" ON notification_templates;
CREATE POLICY "templates_update_admin" ON notification_templates
  FOR UPDATE USING (public.user_role() IN ('admin', 'central'));

DROP POLICY IF EXISTS "templates_delete_admin" ON notification_templates;
CREATE POLICY "templates_delete_admin" ON notification_templates
  FOR DELETE USING (public.user_role() IN ('admin', 'central'));

GRANT SELECT ON notification_templates TO authenticated;
GRANT INSERT ON notification_templates TO authenticated;
GRANT UPDATE ON notification_templates TO authenticated;
GRANT DELETE ON notification_templates TO authenticated;

-- Index
CREATE INDEX IF NOT EXISTS idx_templates_category ON notification_templates(category);

-- 3. Seed default templates
INSERT INTO notification_templates (title, body, type, category, is_system) VALUES
  ('تذكير بالإرساليات', 'يرجى إكمال الإرساليات المعلقة قبل نهاية اليوم.', 'warning', 'submission', true),
  ('صيانة النظام', 'سيكون النظام في وضع الصيانة اليوم من الساعة 10 مساءً حتى 12 مساءً.', 'info', 'system', true),
  ('نقص في اللقاحات', 'تم رصد نقص في أحد اللقاحات. يرجى المراجعة فوراً.', 'error', 'shortage', true),
  ('إشعار عام', '', 'info', 'system', true),
  ('تمت الموافقة', 'تمت الموافقة على طلبك بنجاح.', 'success', 'user', true),
  ('تحديث النظام', 'تم تحديث النظام بإصدار جديد. يرجى مراجعة التغييرات.', 'info', 'system', true),
  ('تنبيه أمني', 'تم رصد نشاط غير معتاد على حسابك. يرجى التحقق.', 'warning', 'user', true)
ON CONFLICT DO NOTHING;

-- 4. Updated_at trigger for templates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_templates_updated_at ON notification_templates;
CREATE TRIGGER trg_templates_updated_at
  BEFORE UPDATE ON notification_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
