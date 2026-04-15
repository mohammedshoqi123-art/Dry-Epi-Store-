-- Chat channels table
CREATE TABLE IF NOT EXISTS chat_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_announcement BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_channels_active ON chat_channels(is_active) WHERE is_active = true;

ALTER TABLE chat_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_channels_select_all" ON chat_channels;
DROP POLICY IF EXISTS "chat_channels_insert_auth" ON chat_channels;
DROP POLICY IF EXISTS "chat_channels_update_creator" ON chat_channels;
DROP POLICY IF EXISTS "chat_channels_delete_admin" ON chat_channels;
CREATE POLICY "chat_channels_select_all" ON chat_channels FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);
CREATE POLICY "chat_channels_insert_auth" ON chat_channels FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "chat_channels_update_creator" ON chat_channels FOR UPDATE USING (created_by = auth.uid() OR public.user_role() = 'admin');
CREATE POLICY "chat_channels_delete_admin" ON chat_channels FOR DELETE USING (public.user_role() = 'admin');

GRANT SELECT, INSERT ON chat_channels TO authenticated;

-- Default channels
INSERT INTO chat_channels (name, description, is_announcement, is_active)
VALUES ('عام', 'القناة العامة للتواصل بين أعضاء الفريق', false, true)
ON CONFLICT DO NOTHING;

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID REFERENCES chat_channels(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  room TEXT NOT NULL DEFAULT 'general',
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_channel ON chat_messages(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread ON chat_messages(is_read, created_at DESC) WHERE is_read = false;

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_select_all" ON chat_messages;
DROP POLICY IF EXISTS "chat_insert_auth" ON chat_messages;
DROP POLICY IF EXISTS "chat_update_own" ON chat_messages;
CREATE POLICY "chat_select_all" ON chat_messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "chat_insert_auth" ON chat_messages FOR INSERT WITH CHECK (sender_id = auth.uid());
CREATE POLICY "chat_update_own" ON chat_messages FOR UPDATE USING (sender_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON chat_messages TO authenticated;

-- Trigger for chat_channels updated_at
DROP TRIGGER IF EXISTS trg_chat_channels_updated ON chat_channels;
CREATE TRIGGER trg_chat_channels_updated BEFORE UPDATE ON chat_channels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Notifications table (if not exists)
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

CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, is_read, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
DROP POLICY IF EXISTS "notifications_insert_system" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications FOR SELECT USING (recipient_id = auth.uid());
CREATE POLICY "notifications_update_own" ON notifications FOR UPDATE USING (recipient_id = auth.uid());
CREATE POLICY "notifications_insert_system" ON notifications FOR INSERT WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE ON notifications TO authenticated;
