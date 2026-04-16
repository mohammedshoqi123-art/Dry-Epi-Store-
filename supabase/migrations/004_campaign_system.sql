-- ============================================================
-- Migration 004: Campaign/Activity System
-- Adds campaign_type to forms and user preferences
-- ============================================================

BEGIN;

-- 1. Add campaign_type column to forms
ALTER TABLE forms ADD COLUMN IF NOT EXISTS campaign_type TEXT NOT NULL DEFAULT 'polio_campaign';

-- Add index for filtering
CREATE INDEX IF NOT EXISTS idx_forms_campaign_type ON forms(campaign_type) WHERE deleted_at IS NULL;

-- Add check constraint
ALTER TABLE forms DROP CONSTRAINT IF EXISTS forms_campaign_type_check;
ALTER TABLE forms ADD CONSTRAINT forms_campaign_type_check
  CHECK (campaign_type IN ('polio_campaign', 'integrated_activity'));

-- 2. Add active_campaign to profiles (user preference)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS active_campaign TEXT NOT NULL DEFAULT 'polio_campaign';

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_active_campaign_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_active_campaign_check
  CHECK (active_campaign IN ('polio_campaign', 'integrated_activity'));

-- 3. Assign existing forms to campaigns
-- Polio Campaign forms
UPDATE forms SET campaign_type = 'polio_campaign'
WHERE title_ar LIKE '%شلل%'
  AND deleted_at IS NULL;

-- Integrated Activity forms
UPDATE forms SET campaign_type = 'integrated_activity'
WHERE (title_ar LIKE '%ايصالي%' OR title_ar LIKE '%تكميلي%' OR title_ar LIKE '%النشاط الإيصالي%')
  AND deleted_at IS NULL;

-- 4. Soft-delete the 3 unwanted forms
UPDATE forms SET deleted_at = now()
WHERE title_ar IN (
  'تقرير نقص التجهيزات',
  'تقرير الزيارات الميدانية',
  'استمارة مراقبة التطعيم',
  'Equipment Shortage Report',
  'Field Visit Report',
  'Vaccination Monitoring Form'
)
AND deleted_at IS NULL;

-- 5. RPC: get user's active campaign
CREATE OR REPLACE FUNCTION get_active_campaign()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT active_campaign FROM profiles WHERE id = auth.uid()),
    'polio_campaign'
  );
$$;

-- 6. RPC: set user's active campaign
CREATE OR REPLACE FUNCTION set_active_campaign(campaign TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF campaign NOT IN ('polio_campaign', 'integrated_activity') THEN
    RAISE EXCEPTION 'Invalid campaign type: %', campaign;
  END IF;

  UPDATE profiles
  SET active_campaign = campaign, updated_at = now()
  WHERE id = auth.uid();
END;
$$;

-- 7. Update getForms function to accept campaign filter
CREATE OR REPLACE FUNCTION get_forms_by_campaign(campaign TEXT DEFAULT NULL)
RETURNS SETOF forms
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT * FROM forms
  WHERE deleted_at IS NULL
    AND is_active = true
    AND (campaign IS NULL OR campaign_type = campaign)
  ORDER BY created_at DESC;
$$;

COMMIT;
