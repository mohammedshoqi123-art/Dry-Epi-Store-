-- ============================================================
-- EPI Supervisor — Migration 004: Improvements
-- Applied from expert audit recommendations
-- ============================================================

BEGIN;

-- ============================================================
-- 1. NOTIFICATIONS TABLE (persistent, DB-backed)
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',       -- info, success, warning, error, sync
  category TEXT DEFAULT 'general',         -- general, form, sync, system
  data JSONB DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT USING (recipient_id = auth.uid());

CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE USING (recipient_id = auth.uid());

-- System can insert (SECURITY DEFINER bypass)
CREATE POLICY "notifications_insert_system" ON notifications
  FOR INSERT WITH CHECK (true);

CREATE INDEX idx_notifications_recipient_unread ON notifications(recipient_id, is_read, created_at DESC);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- 2. BACKUP HISTORY TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS backup_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backup_type TEXT NOT NULL,              -- full, incremental, manual
  status TEXT NOT NULL DEFAULT 'pending', -- pending, running, completed, failed
  file_path TEXT,
  file_size_bytes BIGINT,
  tables_included TEXT[],
  record_count INTEGER,
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  created_by UUID REFERENCES profiles(id)
);

ALTER TABLE backup_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "backup_admin_only" ON backup_history
  FOR ALL USING (public.user_role() = 'admin');

CREATE INDEX idx_backup_history_status ON backup_history(status, created_at DESC);

-- ============================================================
-- 3. ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================================

-- Compound index for common queries
CREATE INDEX IF NOT EXISTS idx_submissions_form_status_date
  ON form_submissions(form_id, status, created_at DESC)
  WHERE deleted_at IS NULL;

-- Index for today's submissions
CREATE INDEX IF NOT EXISTS idx_submissions_today
  ON form_submissions(created_at)
  WHERE created_at >= CURRENT_DATE;

-- Index for offline_id uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_submission_offline_unique
  ON form_submissions(submitted_by, offline_id)
  WHERE offline_id IS NOT NULL;

-- ============================================================
-- 4. DASHBOARD STATS FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_gov_id UUID;
  v_dist_id UUID;
  v_result JSON;
BEGIN
  SELECT role, governorate_id, district_id
  INTO v_role, v_gov_id, v_dist_id
  FROM profiles WHERE id = p_user_id AND is_active = true;

  IF v_role IS NULL THEN
    RETURN '{"error": "User not found or inactive"}'::JSON;
  END IF;

  IF v_role IN ('admin', 'central') THEN
    SELECT json_build_object(
      'role', v_role,
      'total_users', (SELECT COUNT(*) FROM profiles WHERE is_active = true AND deleted_at IS NULL),
      'total_forms', (SELECT COUNT(*) FROM forms WHERE is_active = true AND deleted_at IS NULL),
      'total_submissions', (SELECT COUNT(*) FROM form_submissions WHERE deleted_at IS NULL),
      'pending_reviews', (SELECT COUNT(*) FROM form_submissions WHERE status = 'pending' AND deleted_at IS NULL),
      'today_submissions', (SELECT COUNT(*) FROM form_submissions WHERE created_at::date = CURRENT_DATE AND deleted_at IS NULL),
      'week_submissions', (SELECT COUNT(*) FROM form_submissions WHERE created_at >= date_trunc('week', now()) AND deleted_at IS NULL),
      'total_shortages', (SELECT COUNT(*) FROM supply_shortages WHERE is_resolved = false AND deleted_at IS NULL),
      'critical_shortages', (SELECT COUNT(*) FROM supply_shortages WHERE severity = 'critical' AND is_resolved = false AND deleted_at IS NULL),
      'unread_notifications', (SELECT COUNT(*) FROM notifications WHERE recipient_id = p_user_id AND is_read = false),
      'submissions_by_status', (
        SELECT COALESCE(json_agg(json_build_object('status', status, 'count', count)), '[]'::JSON)
        FROM (
          SELECT status, COUNT(*) as count
          FROM form_submissions
          WHERE deleted_at IS NULL
          GROUP BY status
        ) s
      ),
      'submissions_by_governorate', (
        SELECT COALESCE(json_agg(json_build_object(
          'governorate_id', g.id,
          'governorate_name', g.name_ar,
          'count', COALESCE(sub.count, 0),
          'pending', COALESCE(sub.pending, 0)
        ) ORDER BY COALESCE(sub.count, 0) DESC), '[]'::JSON)
        FROM governorates g
        LEFT JOIN (
          SELECT governorate_id,
            COUNT(*) as count,
            COUNT(*) FILTER (WHERE status = 'pending') as pending
          FROM form_submissions
          WHERE deleted_at IS NULL
          GROUP BY governorate_id
        ) sub ON g.id = sub.governorate_id
        WHERE g.deleted_at IS NULL
      )
    ) INTO v_result;

  ELSIF v_role = 'governorate' THEN
    SELECT json_build_object(
      'role', v_role,
      'governorate_id', v_gov_id,
      'total_users', (SELECT COUNT(*) FROM profiles WHERE governorate_id = v_gov_id AND is_active = true AND deleted_at IS NULL),
      'total_submissions', (SELECT COUNT(*) FROM form_submissions WHERE governorate_id = v_gov_id AND deleted_at IS NULL),
      'pending_reviews', (SELECT COUNT(*) FROM form_submissions WHERE governorate_id = v_gov_id AND status = 'pending' AND deleted_at IS NULL),
      'today_submissions', (SELECT COUNT(*) FROM form_submissions WHERE governorate_id = v_gov_id AND created_at::date = CURRENT_DATE AND deleted_at IS NULL),
      'week_submissions', (SELECT COUNT(*) FROM form_submissions WHERE governorate_id = v_gov_id AND created_at >= date_trunc('week', now()) AND deleted_at IS NULL),
      'shortages', (SELECT COUNT(*) FROM supply_shortages WHERE governorate_id = v_gov_id AND is_resolved = false AND deleted_at IS NULL),
      'unread_notifications', (SELECT COUNT(*) FROM notifications WHERE recipient_id = p_user_id AND is_read = false)
    ) INTO v_result;

  ELSIF v_role = 'district' THEN
    SELECT json_build_object(
      'role', v_role,
      'district_id', v_dist_id,
      'my_submissions', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND deleted_at IS NULL),
      'pending', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'pending' AND deleted_at IS NULL),
      'approved', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'approved' AND deleted_at IS NULL),
      'rejected', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'rejected' AND deleted_at IS NULL),
      'unread_notifications', (SELECT COUNT(*) FROM notifications WHERE recipient_id = p_user_id AND is_read = false)
    ) INTO v_result;

  ELSE -- data_entry
    SELECT json_build_object(
      'role', v_role,
      'my_submissions', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND deleted_at IS NULL),
      'pending', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'pending' AND deleted_at IS NULL),
      'approved', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'approved' AND deleted_at IS NULL),
      'rejected', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'rejected' AND deleted_at IS NULL),
      'drafts', (SELECT COUNT(*) FROM form_submissions WHERE submitted_by = p_user_id AND status = 'draft' AND deleted_at IS NULL),
      'unread_notifications', (SELECT COUNT(*) FROM notifications WHERE recipient_id = p_user_id AND is_read = false)
    ) INTO v_result;
  END IF;

  RETURN COALESCE(v_result, '{}'::JSON);
END;
$$;

-- ============================================================
-- 5. GOVERNORATE REPORT FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_governorate_report(
  p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days')::DATE,
  p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  governorate_id UUID,
  governorate_name TEXT,
  total_submissions BIGINT,
  approved BIGINT,
  pending BIGINT,
  rejected BIGINT,
  submitted BIGINT,
  completion_rate NUMERIC,
  avg_daily_submissions NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    g.id AS governorate_id,
    g.name_ar::TEXT AS governorate_name,
    COUNT(fs.id) AS total_submissions,
    COUNT(fs.id) FILTER (WHERE fs.status = 'approved') AS approved,
    COUNT(fs.id) FILTER (WHERE fs.status = 'pending') AS pending,
    COUNT(fs.id) FILTER (WHERE fs.status = 'rejected') AS rejected,
    COUNT(fs.id) FILTER (WHERE fs.status = 'submitted') AS submitted,
    ROUND(
      COUNT(fs.id) FILTER (WHERE fs.status = 'approved')::NUMERIC /
      NULLIF(COUNT(fs.id), 0) * 100, 2
    ) AS completion_rate,
    ROUND(
      COUNT(fs.id)::NUMERIC /
      NULLIF(p_end_date - p_start_date, 0), 2
    ) AS avg_daily_submissions
  FROM governorates g
  LEFT JOIN form_submissions fs ON g.id = fs.governorate_id
    AND fs.created_at::DATE BETWEEN p_start_date AND p_end_date
    AND fs.deleted_at IS NULL
  WHERE g.deleted_at IS NULL
  GROUP BY g.id, g.name_ar
  ORDER BY total_submissions DESC;
END;
$$;

-- ============================================================
-- 6. AUTO-NOTIFY ON NEW SUBMISSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_on_submission()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Notify supervisors (admin, central) + relevant governorate admin
  INSERT INTO notifications (recipient_id, title, body, type, category, data)
  SELECT
    p.id,
    'استمارة جديدة',
    'تم تقديم استمارة جديدة في ' || COALESCE(
      (SELECT name_ar FROM governorates WHERE id = NEW.governorate_id),
      'غير محدد'
    ),
    'info',
    'form',
    json_build_object('submission_id', NEW.id, 'form_id', NEW.form_id)
  FROM profiles p
  WHERE p.is_active = true
    AND p.deleted_at IS NULL
    AND p.id != NEW.submitted_by
    AND (
      p.role IN ('admin', 'central')
      OR (p.role = 'governorate' AND p.governorate_id = NEW.governorate_id)
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_submission ON form_submissions;
CREATE TRIGGER trigger_notify_submission
  AFTER INSERT ON form_submissions
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_submission();

-- ============================================================
-- 7. AUTO-NOTIFY ON SUBMISSION STATUS CHANGE
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status_label TEXT;
  v_type TEXT;
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  CASE NEW.status
    WHEN 'approved' THEN
      v_status_label := 'تمت الموافقة';
      v_type := 'success';
    WHEN 'rejected' THEN
      v_status_label := 'تم الرفض';
      v_type := 'error';
    WHEN 'reviewed' THEN
      v_status_label := 'تمت المراجعة';
      v_type := 'info';
    ELSE
      RETURN NEW;
  END CASE;

  INSERT INTO notifications (recipient_id, title, body, type, category, data)
  VALUES (
    NEW.submitted_by,
    'تحديث حالة الاستمارة',
    'تم ' || v_status_label || ' على استمارتك' ||
      CASE WHEN NEW.review_notes IS NOT NULL THEN ': ' || NEW.review_notes ELSE '' END,
    v_type,
    'form',
    json_build_object('submission_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_status_change ON form_submissions;
CREATE TRIGGER trigger_notify_status_change
  AFTER UPDATE OF status ON form_submissions
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_status_change();

-- ============================================================
-- 8. ENHANCED APP SETTINGS (additional keys)
-- ============================================================

INSERT INTO app_settings (key, value, label_ar, type, category) VALUES
  ('notification_enabled', 'true', 'تفعيل الإشعارات', 'boolean', 'notifications'),
  ('backup_enabled', 'true', 'تفعيل النسخ الاحتياطي', 'boolean', 'backup'),
  ('backup_interval_hours', '24', 'فترة النسخ الاحتياطي بالساعات', 'number', 'backup'),
  ('max_photo_size_mb', '10', 'أقصى حجم للصورة بالميجا', 'number', 'uploads'),
  ('max_photos_per_submission', '5', 'أقصى عدد صور لكل إرسال', 'number', 'uploads'),
  ('auto_approve_forms', 'false', 'القبول التلقائي للنماذج', 'boolean', 'workflow'),
  ('session_timeout_minutes', '480', 'مهلة انتهاء الجلسة بالدقائق', 'number', 'security'),
  ('max_login_attempts', '5', 'أقصى عدد محاولات تسجيل الدخول', 'number', 'security')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 9. DELETE OLD RATE LIMITS (cleanup function)
-- ============================================================

CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limits()
RETURNS void
LANGUAGE sql SECURITY DEFINER
AS $$
  DELETE FROM rate_limits WHERE window_start < now() - INTERVAL '2 hours';
$$;

-- ============================================================
-- 10. SUBMISSION QUALITY CHECK FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_submission_data(
  p_data JSONB,
  p_schema JSONB
)
RETURNS TABLE(field_name TEXT, error_message TEXT, error_code TEXT)
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_field JSONB;
  v_field_name TEXT;
  v_field_type TEXT;
  v_required BOOLEAN;
  v_value JSONB;
BEGIN
  IF p_schema IS NULL OR jsonb_typeof(p_schema) != 'object' THEN
    RETURN;
  END IF;

  -- Iterate over schema fields
  FOR v_field IN
    SELECT jsonb_array_elements(p_schema->'fields')
  LOOP
    v_field_name := v_field->>'name';
    v_field_type := v_field->>'type';
    v_required := COALESCE((v_field->>'required')::BOOLEAN, false);
    v_value := p_data->v_field_name;

    -- Required check
    IF v_required AND (v_value IS NULL OR v_value = 'null'::JSONB OR v_value = '""'::JSONB) THEN
      field_name := v_field_name;
      error_message := 'الحقل "' || v_field_name || '" مطلوب';
      error_code := 'REQUIRED';
      RETURN NEXT;
      CONTINUE;
    END IF;

    IF v_value IS NULL OR v_value = 'null'::JSONB THEN
      CONTINUE;
    END IF;

    -- Type checks
    CASE v_field_type
      WHEN 'number' THEN
        IF jsonb_typeof(v_value) != 'number' THEN
          field_name := v_field_name;
          error_message := 'الحقل "' || v_field_name || '" يجب أن يكون رقماً';
          error_code := 'INVALID_TYPE';
          RETURN NEXT;
        END IF;
      WHEN 'text', 'textarea' THEN
        IF jsonb_typeof(v_value) != 'string' THEN
          field_name := v_field_name;
          error_message := 'الحقل "' || v_field_name || '" يجب أن يكون نصاً';
          error_code := 'INVALID_TYPE';
          RETURN NEXT;
        END IF;
      WHEN 'date' THEN
        IF jsonb_typeof(v_value) != 'string' THEN
          field_name := v_field_name;
          error_message := 'التاريخ في "' || v_field_name || '" غير صحيح';
          error_code := 'INVALID_DATE';
          RETURN NEXT;
        END IF;
    END CASE;
  END LOOP;
END;
$$;

COMMIT;
