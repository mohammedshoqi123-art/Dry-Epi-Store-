-- ============================================================
-- Migration 005: Campaign Filtering on Submissions
-- Denormalizes campaign_type on form_submissions for fast filtering
-- ============================================================

BEGIN;

-- 1. Add campaign_type to form_submissions (denormalized)
ALTER TABLE form_submissions ADD COLUMN IF NOT EXISTS campaign_type TEXT NOT NULL DEFAULT 'polio_campaign';

ALTER TABLE form_submissions DROP CONSTRAINT IF EXISTS form_submissions_campaign_type_check;
ALTER TABLE form_submissions ADD CONSTRAINT form_submissions_campaign_type_check
  CHECK (campaign_type IN ('polio_campaign', 'integrated_activity'));

-- Index for fast filtering
CREATE INDEX IF NOT EXISTS idx_submissions_campaign ON form_submissions(campaign_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_submissions_campaign_status ON form_submissions(campaign_type, status) WHERE deleted_at IS NULL;

-- 2. Backfill existing submissions from their form's campaign_type
UPDATE form_submissions fs
SET campaign_type = f.campaign_type
FROM forms f
WHERE fs.form_id = f.id
  AND fs.deleted_at IS NULL;

-- 3. Trigger: auto-set campaign_type on insert
CREATE OR REPLACE FUNCTION set_submission_campaign()
RETURNS TRIGGER AS $$
BEGIN
  SELECT campaign_type INTO NEW.campaign_type
  FROM forms WHERE id = NEW.form_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_submission_campaign ON form_submissions;
CREATE TRIGGER trg_set_submission_campaign
  BEFORE INSERT ON form_submissions
  FOR EACH ROW EXECUTE FUNCTION set_submission_campaign();

-- 4. Update get_governorate_report to accept campaign filter
CREATE OR REPLACE FUNCTION get_governorate_report(
  p_campaign TEXT DEFAULT NULL,
  p_governorate_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
  governorate_id UUID,
  governorate_name TEXT,
  total_submissions BIGINT,
  submitted BIGINT,
  reviewed BIGINT,
  approved BIGINT,
  rejected BIGINT,
  draft BIGINT,
  gps_submissions BIGINT,
  photo_submissions BIGINT
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    g.id AS governorate_id,
    g.name_ar AS governorate_name,
    COUNT(fs.id) AS total_submissions,
    COUNT(*) FILTER (WHERE fs.status = 'submitted') AS submitted,
    COUNT(*) FILTER (WHERE fs.status = 'reviewed') AS reviewed,
    COUNT(*) FILTER (WHERE fs.status = 'approved') AS approved,
    COUNT(*) FILTER (WHERE fs.status = 'rejected') AS rejected,
    COUNT(*) FILTER (WHERE fs.status = 'draft') AS draft,
    COUNT(*) FILTER (WHERE fs.gps_lat IS NOT NULL) AS gps_submissions,
    COUNT(*) FILTER (WHERE array_length(fs.photos, 1) > 0) AS photo_submissions
  FROM governorates g
  LEFT JOIN form_submissions fs ON fs.governorate_id = g.id
    AND fs.deleted_at IS NULL
    AND (p_campaign IS NULL OR fs.campaign_type = p_campaign)
    AND (p_start_date IS NULL OR fs.created_at >= p_start_date)
    AND (p_end_date IS NULL OR fs.created_at <= p_end_date)
  WHERE g.deleted_at IS NULL
    AND (p_governorate_id IS NULL OR g.id = p_governorate_id)
  GROUP BY g.id, g.name_ar
  ORDER BY g.name_ar;
$$;

-- 5. Update get_analytics to filter by campaign
CREATE OR REPLACE FUNCTION get_analytics(
  p_campaign TEXT DEFAULT NULL,
  p_governorate_id UUID DEFAULT NULL,
  p_district_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_submissions', COUNT(*),
    'by_status', json_object_agg(status, cnt),
    'by_campaign', json_object_agg(campaign_type, campaign_cnt),
    'gps_coverage', ROUND(100.0 * COUNT(*) FILTER (WHERE gps_lat IS NOT NULL) / GREATEST(COUNT(*), 1), 1),
    'photo_coverage', ROUND(100.0 * COUNT(*) FILTER (WHERE array_length(photos, 1) > 0) / GREATEST(COUNT(*), 1), 1),
    'avg_daily_submissions', ROUND(COUNT(*)::numeric / GREATEST(EXTRACT(DAY FROM COALESCE(p_end_date::timestamp, now()) - COALESCE(p_start_date::timestamp, now() - interval '30 days')), 1), 1)
  ) INTO result
  FROM (
    SELECT *,
      COUNT(*) OVER (PARTITION BY status) AS cnt,
      COUNT(*) OVER (PARTITION BY campaign_type) AS campaign_cnt
    FROM form_submissions
    WHERE deleted_at IS NULL
      AND (p_campaign IS NULL OR campaign_type = p_campaign)
      AND (p_governorate_id IS NULL OR governorate_id = p_governorate_id)
      AND (p_district_id IS NULL OR district_id = p_district_id)
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
  ) sub;
  RETURN result;
END;
$$;

COMMIT;
