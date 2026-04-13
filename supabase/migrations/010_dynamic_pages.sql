-- Dynamic pages for admin-managed content
CREATE TABLE IF NOT EXISTS pages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug TEXT NOT NULL UNIQUE,
  title_ar TEXT NOT NULL,
  content_ar JSONB NOT NULL DEFAULT '{}',
  icon TEXT,
  show_in_nav BOOLEAN DEFAULT false,
  nav_order INTEGER DEFAULT 99,
  roles TEXT[] DEFAULT ARRAY['admin'],
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pages viewable by authenticated" ON pages
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = true);

-- Fix: use roles that actually exist in the user_role enum
-- (no 'supervisor' — use 'admin' and 'central')
CREATE POLICY "Pages manageable by admins" ON pages
  FOR ALL USING (public.user_role() IN ('admin', 'central'));
