-- ============================================================
-- RLS Optimization & Rate Limiting Migration
-- Version: 2.1.0
-- Fixes N+1 query issues in RLS policies and adds rate limiting
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Optimized user context function (single query for all RLS checks)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_context()
RETURNS TABLE(
  user_id UUID,
  role user_role,
  governorate_id UUID,
  district_id UUID
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, role, governorate_id, district_id
  FROM profiles
  WHERE id = auth.uid()
  LIMIT 1;
$$;

-- ============================================================
-- 2. Replace per-row RLS functions with optimized single-query version
-- ============================================================

-- Drop old policies that use repeated function calls
DROP POLICY IF EXISTS "submissions_select_district" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_governorate" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_central_admin" ON form_submissions;
DROP POLICY IF EXISTS "submissions_update_reviewer" ON form_submissions;
DROP POLICY IF EXISTS "submissions_select_hierarchical" ON form_submissions;

-- Optimized SELECT policy using CTE pattern
CREATE POLICY "submissions_select_hierarchical" ON form_submissions
FOR SELECT USING (
  submitted_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.get_user_context() ctx
    WHERE
      (ctx.role IN ('admin', 'central')) OR
      (ctx.role = 'governorate' AND ctx.governorate_id = form_submissions.governorate_id) OR
      (ctx.role = 'district' AND ctx.district_id = form_submissions.district_id)
  )
);

-- Optimized UPDATE policy for reviewers
CREATE POLICY "submissions_update_reviewer" ON form_submissions
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.get_user_context() ctx
    WHERE
      (ctx.role IN ('admin', 'central')) OR
      (ctx.role = 'governorate' AND ctx.governorate_id = form_submissions.governorate_id) OR
      (ctx.role = 'district' AND ctx.district_id = form_submissions.district_id)
  )
);

-- Optimize profiles RLS similarly
DROP POLICY IF EXISTS "profiles_select_governorate" ON profiles;

CREATE POLICY "profiles_select_governorate" ON profiles
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.get_user_context() ctx
    WHERE ctx.role = 'governorate' AND ctx.governorate_id = profiles.governorate_id
  )
);

-- ============================================================
-- 3. Composite index for RLS lookup optimization
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_submissions_auth_lookup
  ON form_submissions(submitted_by, governorate_id, district_id)
  WHERE deleted_at IS NULL;

-- ============================================================
-- 4. Rate limiting table and function
-- ============================================================
CREATE TABLE IF NOT EXISTS rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  reset_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, endpoint)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_reset
  ON rate_limits(reset_at)
  WHERE reset_at < NOW();

-- Clean up expired rate limit entries periodically
CREATE OR REPLACE FUNCTION cleanup_expired_rate_limits()
RETURNS void
LANGUAGE sql
AS $$
  DELETE FROM rate_limits WHERE reset_at < NOW();
$$;

CREATE OR REPLACE FUNCTION public.check_and_increment_rate_limit(
  p_user_id UUID,
  p_endpoint TEXT,
  p_window_seconds INTEGER DEFAULT 60,
  p_max_requests INTEGER DEFAULT 10
)
RETURNS TABLE(allowed BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
  v_reset_at TIMESTAMPTZ;
BEGIN
  SELECT count, reset_at INTO v_count, v_reset_at
  FROM rate_limits
  WHERE user_id = p_user_id AND endpoint = p_endpoint
  FOR UPDATE;

  IF v_count IS NULL OR NOW() > v_reset_at THEN
    INSERT INTO rate_limits (user_id, endpoint, count, reset_at)
    VALUES (p_user_id, p_endpoint, 1, NOW() + (p_window_seconds || ' seconds')::INTERVAL)
    ON CONFLICT (user_id, endpoint)
    DO UPDATE SET count = 1, reset_at = NOW() + (p_window_seconds || ' seconds')::INTERVAL;
    RETURN QUERY SELECT true;
    RETURN;
  END IF;

  IF v_count >= p_max_requests THEN
    RETURN QUERY SELECT false;
    RETURN;
  END IF;

  UPDATE rate_limits
  SET count = count + 1
  WHERE user_id = p_user_id AND endpoint = p_endpoint;

  RETURN QUERY SELECT true;
END;
$$;

-- RLS for rate_limits
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rate_limits_own" ON rate_limits
FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- 5. Materialized view for analytics performance
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_submission_stats AS
SELECT
  governorate_id,
  district_id,
  form_id,
  status,
  DATE_TRUNC('day', created_at) AS submission_date,
  COUNT(*) AS count
FROM form_submissions
WHERE deleted_at IS NULL
GROUP BY 1, 2, 3, 4, 5;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_stats_unique
  ON mv_submission_stats(governorate_id, district_id, form_id, status, submission_date);

CREATE INDEX IF NOT EXISTS idx_mv_stats_gov_date
  ON mv_submission_stats(governorate_id, submission_date);

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_submission_stats()
RETURNS void
LANGUAGE sql
AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_submission_stats;
$$;

-- ============================================================
-- 6. Idempotency key column for form_submissions
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'form_submissions' AND column_name = 'idempotency_key'
  ) THEN
    ALTER TABLE form_submissions ADD COLUMN idempotency_key TEXT UNIQUE;
  END IF;
END $$;

-- Index for idempotency lookups
CREATE INDEX IF NOT EXISTS idx_submissions_idempotency
  ON form_submissions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ============================================================
-- 7. Schema versioning for forms
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'forms' AND column_name = 'schema_version'
  ) THEN
    ALTER TABLE forms ADD COLUMN schema_version INTEGER DEFAULT 1;
  END IF;
END $$;

-- ============================================================
-- 8. App config table for force-update mechanism
-- ============================================================
CREATE TABLE IF NOT EXISTS app_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default minimum version
INSERT INTO app_config (key, value)
VALUES ('min_app_version', '"1.0.0"'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- RLS for app_config (read-only for all authenticated users)
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_config_select_auth" ON app_config
FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "app_config_modify_admin" ON app_config
FOR ALL USING (public.user_role() = 'admin');

COMMIT;
