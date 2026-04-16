-- ============================================================
-- 🧹 قالب حذف البيانات غير المرغوبة
-- ⚠️ عدّل قائمة المعرفات (UUIDs) بناءً على نتائج diagnostic_queries.sql
-- ============================================================

BEGIN;

-- ═══ 1. حذف محافظات محددة (ضع المعرفات هنا) ═══
/*
UPDATE governorates
SET deleted_at = now(), updated_at = now()
WHERE id IN (
  'PUT-GOVERNORATE-UUID-HERE',
  'PUT-ANOTHER-UUID-HERE'
);
*/

-- ═══ 2. حذف مديريات محددة ═══
/*
UPDATE districts
SET deleted_at = now(), updated_at = now()
WHERE id IN (
  'PUT-DISTRICT-UUID-HERE'
);
*/

-- ═══ 3. حذف مرافق صحية محددة ═══
/*
UPDATE health_facilities
SET deleted_at = now(), updated_at = now()
WHERE id IN (
  'PUT-FACILITY-UUID-HERE'
);
*/

-- ═══ 4. حذف كل المديريات التابعة لمحافظة معينة ═══
/*
UPDATE districts
SET deleted_at = now(), updated_at = now()
WHERE governorate_id = 'PUT-GOVERNORATE-UUID-HERE';
*/

-- ═══ 5. حذف كل المرافق التابعة لمديرية معينة ═══
/*
UPDATE health_facilities
SET deleted_at = now(), updated_at = now()
WHERE district_id = 'PUT-DISTRICT-UUID-HERE';
*/

-- ═══ 6. حذف كل المكررات (يحتفظ بالأقدم ويحذف الباقي) ═══
-- المحافظات المكررة: احتفظ بالأقدم
/*
DELETE FROM governorates
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY name_ar ORDER BY created_at) AS rn
    FROM governorates WHERE deleted_at IS NULL
  ) t WHERE rn > 1
);
*/

-- المديريات المكررة في نفس المحافظة: احتفظ بالأقدم
/*
DELETE FROM districts
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY governorate_id, name_ar ORDER BY created_at) AS rn
    FROM districts WHERE deleted_at IS NULL
  ) t WHERE rn > 1
);
*/

COMMIT;
