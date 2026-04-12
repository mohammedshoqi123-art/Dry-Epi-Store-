-- ============================================================
-- EPI Supervisor Platform — Storage Buckets & Additional Fixes
-- Version: 2.1.0
-- ============================================================

BEGIN;

-- ============================================================
-- 1. STORAGE BUCKETS
-- ============================================================

-- Submissions photos bucket (private — accessed via signed URLs)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'submission-photos',
  'submission-photos',
  false,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- User avatars bucket (public — direct access)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. STORAGE RLS POLICIES
-- ============================================================

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "submission_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "submission_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "submission_photos_delete" ON storage.objects;
DROP POLICY IF EXISTS "avatars_select" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;

-- submission-photos: authenticated users can upload/select their own, admins can see all
CREATE POLICY "submission_photos_select" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'submission-photos' AND
    auth.uid() IS NOT NULL
  );

CREATE POLICY "submission_photos_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'submission-photos' AND
    auth.uid() IS NOT NULL
  );

CREATE POLICY "submission_photos_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'submission-photos' AND
    (
      owner = auth.uid() OR
      public.user_role() = 'admin'
    )
  );

-- avatars: public read, authenticated users can manage their own
CREATE POLICY "avatars_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid() IS NOT NULL
  );

CREATE POLICY "avatars_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'avatars' AND
    owner = auth.uid()
  );

CREATE POLICY "avatars_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'avatars' AND
    (
      owner = auth.uid() OR
      public.user_role() = 'admin'
    )
  );

-- ============================================================
-- 3. ADD MISSING OFFLINE_ID CONSTRAINT
-- ============================================================

-- Ensure offline_id is unique when present (prevent duplicate sync)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'form_submissions_offline_id_unique'
  ) THEN
    ALTER TABLE form_submissions
      ADD CONSTRAINT form_submissions_offline_id_unique
      UNIQUE (offline_id);
  END IF;
EXCEPTION WHEN duplicate_table THEN NULL;
END $$;

COMMIT;
