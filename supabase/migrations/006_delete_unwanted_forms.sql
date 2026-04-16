-- ============================================================
-- Migration 006: Delete Unwanted Forms (Permanent)
-- حذف النماذج غير المرغوبة بشكل نهائي
-- ============================================================

BEGIN;

-- ═══ 1. Soft-delete the 3 unwanted forms (all languages) ═══
UPDATE forms
SET deleted_at = now(), updated_at = now()
WHERE deleted_at IS NULL
  AND (
    title_ar IN (
      'استمارة مراقبة التطعيم',
      'تقرير الزيارات الميدانية',
      'تقرير نقص التجهيزات'
    )
    OR title_en IN (
      'Vaccination Monitoring Form',
      'Field Visit Report',
      'Equipment Shortage Report'
    )
  );

-- Log the deletion
INSERT INTO audit_logs (user_id, action, resource_type, details)
SELECT
  COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
  'delete',
  'forms',
  jsonb_build_object(
    'reason', 'migration_006_cleanup',
    'deleted_forms', ARRAY[title_ar, title_en]
  )
FROM forms
WHERE deleted_at IS NOT NULL
  AND updated_at >= now() - interval '1 second';

-- ═══ 2. Also soft-delete any submissions tied to these forms ═══
-- (Optional: keep data for historical records, just hide from UI)
UPDATE form_submissions fs
SET deleted_at = now(), updated_at = now()
WHERE fs.deleted_at IS NULL
  AND fs.form_id IN (
    SELECT id FROM forms
    WHERE title_ar IN (
      'استمارة مراقبة التطعيم',
      'تقرير الزيارات الميدانية',
      'تقرير نقص التجهيزات'
    )
    OR title_en IN (
      'Vaccination Monitoring Form',
      'Field Visit Report',
      'Equipment Shortage Report'
    )
  );

COMMIT;
