-- ============================================================
-- 🔍 استعلامات الفحص الشامل — المحافظات والمديريات والمرافق
-- شغّل كل قسم على حدة في Supabase SQL Editor
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- 1️⃣  جميع المحافظات (مع عدد المديريات والمرافق)
-- ══════════════════════════════════════════════════════════════
SELECT
  g.id,
  g.name_ar AS المحافظة,
  g.name_en AS name_en,
  g.code AS الكود,
  g.is_active AS نشط,
  g.created_at AS تاريخ_الإضافة,
  (SELECT COUNT(*) FROM districts d WHERE d.governorate_id = g.id AND d.deleted_at IS NULL) AS عدد_المديريات,
  (SELECT COUNT(*) FROM health_facilities hf WHERE hf.governorate_id = g.id AND hf.deleted_at IS NULL) AS عدد_المرافق
FROM governorates g
WHERE g.deleted_at IS NULL
ORDER BY g.name_ar;


-- ══════════════════════════════════════════════════════════════
-- 2️⃣  المحافظات المكررة (نفس الاسم أكثر من مرة)
-- ══════════════════════════════════════════════════════════════
SELECT
  name_ar AS المحافظة_المكررة,
  COUNT(*) AS عدد_التكرارات,
  array_agg(id::text ORDER BY created_at) AS جميع_المعرفات,
  array_agg(created_at::text ORDER BY created_at) AS تواريخ_الإضافة
FROM governorates
WHERE deleted_at IS NULL
GROUP BY name_ar
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;


-- ══════════════════════════════════════════════════════════════
-- 3️⃣  المحافظات بدون كود
-- ══════════════════════════════════════════════════════════════
SELECT
  id,
  name_ar AS المحافظة,
  code AS الكود,
  created_at AS تاريخ_الإضافة
FROM governorates
WHERE deleted_at IS NULL
  AND (code IS NULL OR TRIM(code) = '')
ORDER BY name_ar;


-- ══════════════════════════════════════════════════════════════
-- 4️⃣  جميع المديريات مع المحافظة الأم
-- ══════════════════════════════════════════════════════════════
SELECT
  d.id,
  g.name_ar AS المحافظة,
  d.name_ar AS المديرية,
  d.name_en AS name_en,
  d.code AS الكود,
  d.is_active AS نشط,
  d.created_at AS تاريخ_الإضافة
FROM districts d
LEFT JOIN governorates g ON g.id = d.governorate_id
WHERE d.deleted_at IS NULL
ORDER BY g.name_ar, d.name_ar;


-- ══════════════════════════════════════════════════════════════
-- 5️⃣  المديريات المكررة (نفس الاسم داخل نفس المحافظة)
-- ══════════════════════════════════════════════════════════════
SELECT
  g.name_ar AS المحافظة,
  d.name_ar AS المديرية_المكررة,
  COUNT(*) AS عدد_التكرارات,
  array_agg(d.id::text ORDER BY d.created_at) AS جميع_المعرفات
FROM districts d
JOIN governorates g ON g.id = d.governorate_id
WHERE d.deleted_at IS NULL
GROUP BY g.name_ar, d.name_ar
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;


-- ══════════════════════════════════════════════════════════════
-- 6️⃣  المديريات بدون كود
-- ══════════════════════════════════════════════════════════════
SELECT
  d.id,
  g.name_ar AS المحافظة,
  d.name_ar AS المديرية,
  d.code AS الكود,
  d.created_at AS تاريخ_الإضافة
FROM districts d
LEFT JOIN governorates g ON g.id = d.governorate_id
WHERE d.deleted_at IS NULL
  AND (d.code IS NULL OR TRIM(d.code) = '')
ORDER BY g.name_ar, d.name_ar;


-- ══════════════════════════════════════════════════════════════
-- 7️⃣  جميع المرافق الصحية مع المحافظة والمديرية
-- ══════════════════════════════════════════════════════════════
SELECT
  hf.id,
  g.name_ar AS المحافظة,
  d.name_ar AS المديرية,
  hf.name_ar AS المرفق,
  hf.facility_type AS نوع_المرفق,
  hf.code AS الكود,
  hf.is_active AS نشط,
  hf.created_at AS تاريخ_الإضافة
FROM health_facilities hf
LEFT JOIN governorates g ON g.id = hf.governorate_id
LEFT JOIN districts d ON d.id = hf.district_id
WHERE hf.deleted_at IS NULL
ORDER BY g.name_ar, d.name_ar, hf.name_ar;


-- ══════════════════════════════════════════════════════════════
-- 8️⃣  المرافق الصحية المكررة
-- ══════════════════════════════════════════════════════════════
SELECT
  g.name_ar AS المحافظة,
  d.name_ar AS المديرية,
  hf.name_ar AS المرفق_المكرر,
  COUNT(*) AS عدد_التكرارات,
  array_agg(hf.id::text ORDER BY hf.created_at) AS جميع_المعرفات
FROM health_facilities hf
LEFT JOIN governorates g ON g.id = hf.governorate_id
LEFT JOIN districts d ON d.id = hf.district_id
WHERE hf.deleted_at IS NULL
GROUP BY g.name_ar, d.name_ar, hf.name_ar
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;


-- ══════════════════════════════════════════════════════════════
-- 9️⃣  ملخص سريع — عدد السجلات في كل جدول
-- ══════════════════════════════════════════════════════════════
SELECT 'المحافظات' AS الجدول, COUNT(*) AS العدد,
       COUNT(*) FILTER (WHERE code IS NULL OR TRIM(code) = '') AS بدون_كود,
       COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) AS محذوفة
FROM governorates
UNION ALL
SELECT 'المديريات', COUNT(*),
       COUNT(*) FILTER (WHERE code IS NULL OR TRIM(code) = ''),
       COUNT(*) FILTER (WHERE deleted_at IS NOT NULL)
FROM districts
UNION ALL
SELECT 'المرافق الصحية', COUNT(*),
       COUNT(*) FILTER (WHERE code IS NULL OR TRIM(code) = ''),
       COUNT(*) FILTER (WHERE deleted_at IS NOT NULL)
FROM health_facilities;


-- ══════════════════════════════════════════════════════════════
-- 🔟  المديريات بلا محافظة (orphans)
-- ══════════════════════════════════════════════════════════════
SELECT
  d.id,
  d.name_ar AS المديرية_بلا_محافظة,
  d.governorate_id AS معرف_المحافظة_المفقود,
  d.created_at
FROM districts d
LEFT JOIN governorates g ON g.id = d.governorate_id
WHERE d.deleted_at IS NULL
  AND g.id IS NULL;
