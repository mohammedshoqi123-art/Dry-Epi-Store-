-- supabase/migrations/012_performance_indexes.sql
-- ============================================================
-- Performance Indexes & Optimizations
-- Fixed: correct column names matching schema from 001_initial_schema
-- ============================================================

BEGIN;

-- Drop old objects from previous failed migration attempt
DROP INDEX IF EXISTS idx_forms_name_search;
DROP INDEX IF EXISTS idx_forms_description_search;
DROP INDEX IF EXISTS idx_submissions_form_date;
DROP INDEX IF EXISTS idx_submissions_user_date;
DROP INDEX IF EXISTS idx_submissions_governorate_date;
DROP INDEX IF EXISTS idx_submissions_district_date;
DROP INDEX IF EXISTS idx_submissions_form_status_date;
DROP INDEX IF EXISTS idx_offline_sync_status;
DROP INDEX IF EXISTS idx_offline_retry_count;
DROP INDEX IF EXISTS idx_audit_user_date;
DROP INDEX IF EXISTS idx_audit_entity;
DROP INDEX IF EXISTS idx_mv_governorate_stats_id;
DROP FUNCTION IF EXISTS search_forms(TEXT);
DROP FUNCTION IF EXISTS get_submission_counts(uuid, uuid, timestamptz, timestamptz);
DROP FUNCTION IF EXISTS get_submission_trend(int, uuid);
DROP FUNCTION IF EXISTS refresh_governorate_stats();
DROP FUNCTION IF EXISTS is_admin();
DROP FUNCTION IF EXISTS is_central_or_above();
DROP MATERIALIZED VIEW IF EXISTS mv_governorate_stats;

-- ═══════════════════════════════════════════════════════════════
-- 1. TEXT SEARCH INDEXES (Arabic full-text search)
-- ═══════════════════════════════════════════════════════════════

-- Forms: Arabic text search on title and description
CREATE INDEX IF NOT EXISTS idx_forms_title_search
  ON forms USING gin(to_tsvector('arabic', coalesce(title_ar, '')));

CREATE INDEX IF NOT EXISTS idx_forms_desc_search
  ON forms USING gin(to_tsvector('arabic', coalesce(description_ar, '')));

-- Health facilities: name search
CREATE INDEX IF NOT EXISTS idx_facilities_name_search
  ON health_facilities USING gin(to_tsvector('arabic', coalesce(name_ar, '')));

-- ═══════════════════════════════════════════════════════════════
-- 2. COMPOSITE INDEXES FOR COMMON QUERIES
-- ═══════════════════════════════════════════════════════════════

-- Submissions: form + date (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_submissions_form_date
  ON form_submissions(form_id, created_at DESC) WHERE deleted_at IS NULL;

-- Submissions: user + date
CREATE INDEX IF NOT EXISTS idx_submissions_user_date
  ON form_submissions(submitted_by, created_at DESC) WHERE deleted_at IS NULL;

-- Submissions: governorate + date (for analytics)
CREATE INDEX IF NOT EXISTS idx_submissions_gov_date
  ON form_submissions(governorate_id, created_at DESC) WHERE deleted_at IS NULL;

-- Submissions: district + date
CREATE INDEX IF NOT EXISTS idx_submissions_dist_date
  ON form_submissions(district_id, created_at DESC) WHERE deleted_at IS NULL;

-- Submissions: form + status + date (analytics combo)
CREATE INDEX IF NOT EXISTS idx_submissions_form_status_date
  ON form_submissions(form_id, status, created_at DESC) WHERE deleted_at IS NULL;

-- ═══════════════════════════════════════════════════════════════
-- 3. SEARCH FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Full-text search on forms (Arabic)
CREATE OR REPLACE FUNCTION search_forms(search_query TEXT)
RETURNS SETOF forms AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM forms
  WHERE
    to_tsvector('arabic', coalesce(title_ar, '') || ' ' || coalesce(description_ar, ''))
    @@ plainto_tsquery('arabic', search_query)
  ORDER BY
    ts_rank(
      to_tsvector('arabic', coalesce(title_ar, '') || ' ' || coalesce(description_ar, '')),
      plainto_tsquery('arabic', search_query)
    ) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════
-- 4. MATERIALIZED VIEW FOR DASHBOARD
-- ═══════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_governorate_stats AS
SELECT
  g.id as governorate_id,
  g.name_ar as governorate_name,
  count(fs.id) as total_submissions,
  count(fs.id) FILTER (WHERE fs.status = 'submitted') as submitted,
  count(fs.id) FILTER (WHERE fs.status = 'rejected') as rejected,
  count(fs.id) FILTER (WHERE fs.status = 'draft') as draft,
  count(fs.id) FILTER (WHERE fs.created_at::date = current_date) as today,
  CASE
    WHEN count(fs.id) > 0
    THEN round(count(fs.id) FILTER (WHERE fs.status = 'submitted')::numeric * 100 / count(fs.id), 1)
    ELSE 0
  END as completion_rate,
  count(ss.id) FILTER (WHERE ss.is_resolved = false) as unresolved_shortages,
  count(ss.id) FILTER (WHERE ss.is_resolved = false AND ss.severity = 'critical') as critical_shortages,
  now() as refreshed_at
FROM governorates g
LEFT JOIN form_submissions fs ON fs.governorate_id = g.id AND fs.deleted_at IS NULL
LEFT JOIN supply_shortages ss ON ss.governorate_id = g.id
GROUP BY g.id, g.name_ar;

-- Unique index required for CONCURRENTLY refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_gov_stats_id
  ON mv_governorate_stats(governorate_id);

-- Refresh function
CREATE OR REPLACE FUNCTION refresh_governorate_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_governorate_stats;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 5. GRANTS
-- ═══════════════════════════════════════════════════════════════

GRANT EXECUTE ON FUNCTION search_forms TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_governorate_stats TO service_role;

COMMIT;
