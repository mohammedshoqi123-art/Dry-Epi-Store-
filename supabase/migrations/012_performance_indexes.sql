-- supabase/migrations/012_performance_indexes.sql
-- ============================================================
-- Performance Indexes & Optimizations
-- Created from Expert Review recommendations
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. TEXT SEARCH INDEXES (Arabic full-text search)
-- ═══════════════════════════════════════════════════════════════

-- Enable Arabic text search configuration
CREATE TEXT SEARCH CONFIGURATION arabic (COPY = simple);

-- Forms: Arabic text search on name and description
CREATE INDEX IF NOT EXISTS idx_forms_name_search
  ON forms USING gin(to_tsvector('arabic', coalesce(name, '')));

CREATE INDEX IF NOT EXISTS idx_forms_description_search
  ON forms USING gin(to_tsvector('arabic', coalesce(description, '')));

-- ═══════════════════════════════════════════════════════════════
-- 2. COMPOSITE INDEXES FOR COMMON QUERIES
-- ═══════════════════════════════════════════════════════════════

-- Submissions: form + date (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_submissions_form_date
  ON form_submissions(form_id, created_at DESC);

-- Submissions: user + date
CREATE INDEX IF NOT EXISTS idx_submissions_user_date
  ON form_submissions(user_id, created_at DESC);

-- Submissions: governorate + date (for analytics)
CREATE INDEX IF NOT EXISTS idx_submissions_governorate_date
  ON form_submissions(governorate_id, created_at DESC);

-- Submissions: district + date
CREATE INDEX IF NOT EXISTS idx_submissions_district_date
  ON form_submissions(district_id, created_at DESC);

-- Submissions: status filter (for dashboard counts)
CREATE INDEX IF NOT EXISTS idx_submissions_status
  ON form_submissions(status) WHERE deleted_at IS NULL;

-- Submissions: form + status + date (analytics combo)
CREATE INDEX IF NOT EXISTS idx_submissions_form_status_date
  ON form_submissions(form_id, status, created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- 3. SYNC/QUEUE INDEXES
-- ═══════════════════════════════════════════════════════════════

-- Offline queue: sync status (pending items lookup)
CREATE INDEX IF NOT EXISTS idx_offline_sync_status
  ON offline_queue(sync_status, created_at);

-- Offline queue: retry logic
CREATE INDEX IF NOT EXISTS idx_offline_retry_count
  ON offline_queue(retry_count, last_retry)
  WHERE sync_status = 'pending';

-- ═══════════════════════════════════════════════════════════════
-- 4. SHORTAGES INDEXES
-- ═══════════════════════════════════════════════════════════════

-- Shortages: unresolved by severity (critical dashboard)
CREATE INDEX IF NOT EXISTS idx_shortages_unresolved_severity
  ON supply_shortages(severity, created_at DESC)
  WHERE is_resolved = false;

-- Shortages: by governorate
CREATE INDEX IF NOT EXISTS idx_shortages_governorate
  ON supply_shortages(governorate_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- 5. PROFILES INDEXES
-- ═══════════════════════════════════════════════════════════════

-- Users: role-based lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role
  ON profiles(role);

-- Users: governorate assignment
CREATE INDEX IF NOT EXISTS idx_profiles_governorate
  ON profiles(governorate_id) WHERE governorate_id IS NOT NULL;

-- Users: district assignment
CREATE INDEX IF NOT EXISTS idx_profiles_district
  ON profiles(district_id) WHERE district_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 6. AUDIT LOGS INDEXES
-- ═══════════════════════════════════════════════════════════════

-- Audit: by user + date
CREATE INDEX IF NOT EXISTS idx_audit_user_date
  ON audit_logs(user_id, created_at DESC);

-- Audit: by entity type + entity id
CREATE INDEX IF NOT EXISTS idx_audit_entity
  ON audit_logs(entity_type, entity_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- 7. SEARCH FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Full-text search on forms (Arabic)
CREATE OR REPLACE FUNCTION search_forms(search_query text)
RETURNS SETOF forms AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM forms
  WHERE
    to_tsvector('arabic', coalesce(name, '') || ' ' || coalesce(description, ''))
    @@ plainto_tsquery('arabic', search_query)
  ORDER BY
    ts_rank(
      to_tsvector('arabic', coalesce(name, '') || ' ' || coalesce(description, '')),
      plainto_tsquery('arabic', search_query)
    ) DESC;
END;
$$ LANGUAGE plpgsql;

-- Fast submission count by status (materialized-view alternative)
CREATE OR REPLACE FUNCTION get_submission_counts(
  p_governorate_id uuid DEFAULT NULL,
  p_district_id uuid DEFAULT NULL,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL
)
RETURNS TABLE (
  total bigint,
  submitted bigint,
  rejected bigint,
  pending bigint,
  today bigint,
  completion_rate numeric
) AS $$
DECLARE
  v_total bigint;
  v_submitted bigint;
  v_rejected bigint;
  v_pending bigint;
  v_today bigint;
BEGIN
  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'submitted'),
    count(*) FILTER (WHERE status = 'rejected'),
    count(*) FILTER (WHERE status = 'pending'),
    count(*) FILTER (WHERE created_at::date = current_date)
  INTO v_total, v_submitted, v_rejected, v_pending, v_today
  FROM form_submissions
  WHERE deleted_at IS NULL
    AND (p_governorate_id IS NULL OR governorate_id = p_governorate_id)
    AND (p_district_id IS NULL OR district_id = p_district_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  total := v_total;
  submitted := v_submitted;
  rejected := v_rejected;
  pending := v_pending;
  today := v_today;
  completion_rate := CASE WHEN v_total > 0 THEN round(v_submitted::numeric * 100 / v_total, 1) ELSE 0 END;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- Daily submission trend (last N days)
CREATE OR REPLACE FUNCTION get_submission_trend(
  p_days int DEFAULT 30,
  p_governorate_id uuid DEFAULT NULL
)
RETURNS TABLE (
  date date,
  count bigint,
  submitted bigint,
  rejected bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d::date,
    coalesce(s.total, 0) as count,
    coalesce(s.submitted, 0) as submitted,
    coalesce(s.rejected, 0) as rejected
  FROM generate_series(
    current_date - (p_days - 1),
    current_date,
    '1 day'::interval
  ) d
  LEFT JOIN LATERAL (
    SELECT
      count(*) as total,
      count(*) FILTER (WHERE status = 'submitted') as submitted,
      count(*) FILTER (WHERE status = 'rejected') as rejected
    FROM form_submissions
    WHERE created_at::date = d::date
      AND deleted_at IS NULL
      AND (p_governorate_id IS NULL OR governorate_id = p_governorate_id)
  ) s ON true
  ORDER BY d;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════
-- 8. MATERIALIZED VIEW FOR DASHBOARD (optional, refreshable)
-- ═══════════════════════════════════════════════════════════════

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_governorate_stats AS
SELECT
  g.id as governorate_id,
  g.name_ar as governorate_name,
  count(fs.id) as total_submissions,
  count(fs.id) FILTER (WHERE fs.status = 'submitted') as submitted,
  count(fs.id) FILTER (WHERE fs.status = 'rejected') as rejected,
  count(fs.id) FILTER (WHERE fs.status = 'pending') as pending,
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_governorate_stats_id
  ON mv_governorate_stats(governorate_id);

-- Refresh function (call via pg_cron or Edge Function)
CREATE OR REPLACE FUNCTION refresh_governorate_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_governorate_stats;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 9. ROW-LEVEL SECURITY OPTIMIZATION
-- ═══════════════════════════════════════════════════════════════

-- Optimized admin check (cached in subquery)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_central_or_above()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('admin', 'central')
  );
$$ LANGUAGE sql STABLE;

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION search_forms TO authenticated;
GRANT EXECUTE ON FUNCTION get_submission_counts TO authenticated;
GRANT EXECUTE ON FUNCTION get_submission_trend TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_governorate_stats TO service_role;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_central_or_above TO authenticated;
