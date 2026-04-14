-- ============================================================
-- EPI Supervisor — Seed Data
-- Yemen Governorates + Districts + Sample Forms
-- ⚠️ Run AFTER 001_schema.sql
-- ============================================================

BEGIN;

-- ============================================================
-- 1. YEMEN GOVERNORATES (22 governorates + Sana'a City)
-- ============================================================
INSERT INTO governorates (name_ar, name_en, code, center_lat, center_lng, population) VALUES
  ('صنعاء', 'Sana''a', 'SAN', 15.3694, 44.1910, 3292000),
  ('عدن', 'Aden', 'ADE', 12.7855, 45.0187, 864000),
  ('تعز', 'Taiz', 'TAZ', 13.5790, 44.0206, 2920000),
  ('الحديدة', 'Al Hudaydah', 'HOD', 14.7973, 42.9524, 3050000),
  ('إب', 'Ibb', 'IBB', 13.9667, 44.1833, 2630000),
  ('ذمار', 'Dhamar', 'DHA', 14.5591, 44.4052, 1740000),
  ('حضرموت', 'Hadhramaut', 'HAD', 15.4000, 48.3400, 1330000),
  ('مأرب', 'Marib', 'MAR', 15.4685, 45.3251, 520000),
  ('الجوف', 'Al Jawf', 'JOF', 16.7902, 45.2935, 560000),
  ('صعدة', 'Sa''ada', 'SAD', 16.9400, 43.7630, 780000),
  ('البيضاء', 'Al Bayda', 'BAY', 14.1167, 45.4500, 680000),
  ('لحج', 'Lahij', 'LAH', 13.0567, 44.8819, 920000),
  ('أبين', 'Abyan', 'ABY', 13.4500, 46.0500, 560000),
  ('شبوة', 'Shabwah', 'SHB', 14.5300, 46.8300, 590000),
  ('المهرة', 'Al Mahrah', 'MAH', 15.5000, 51.6500, 420000),
  ('ريمة', 'Raymah', 'RAY', 14.6278, 43.6000, 510000),
  ('المحويت', 'Al Mahwit', 'MHW', 15.4700, 43.5500, 620000),
  ('عمران', 'Amran', 'AMR', 15.6594, 43.9439, 1080000),
  ('الضالع', 'Al Dhale''', 'DHA2', 13.6957, 44.7303, 620000),
  ('حجة', 'Hajjah', 'HAJ', 15.6917, 43.6021, 1830000),
  ('سقطرى', 'Socotra', 'SOC', 12.4634, 53.8234, 60000),
  ('أرخبيل سقطرى', 'Socotra Archipelago', 'SOCA', 12.2000, 53.9000, 44000)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. SAMPLE DISTRICTS (selected from key governorates)
-- ============================================================
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('SAN', 'الوحدة', 'Al Wahda', 'SAN-01', 15.3547, 44.2094),
  ('SAN', 'السبعين', 'Al Sabaeen', 'SAN-02', 15.3610, 44.1870),
  ('SAN', 'التحرير', 'Al Tahrir', 'SAN-03', 15.3490, 44.1950),
  ('SAN', 'معين', 'Ma''in', 'SAN-04', 15.3780, 44.1750),
  ('SAN', 'الظاهر', 'Al Dhahir', 'SAN-05', 15.3850, 44.2100),
  ('ADE', 'المعلا', 'Al Mualla', 'ADE-01', 12.7794, 44.9919),
  ('ADE', 'كريتر', 'Crater', 'ADE-02', 12.7775, 45.0385),
  ('ADE', 'التواهي', 'Al Tawahi', 'ADE-03', 12.7835, 44.9770),
  ('ADE', 'المنصورة', 'Al Mansura', 'ADE-04', 12.7950, 45.0050),
  ('ADE', 'دار سعد', 'Dar Saad', 'ADE-05', 12.8100, 45.0200),
  ('TAZ', 'المظفر', 'Al Mudhaffar', 'TAZ-01', 13.5732, 44.0118),
  ('TAZ', 'القاهرة', 'Al Qahira', 'TAZ-02', 13.5830, 44.0260),
  ('TAZ', 'صالة', 'Salah', 'TAZ-03', 13.5650, 44.0350),
  ('HOD', 'الحالي', 'Al Hali', 'HOD-01', 14.7900, 42.9400),
  ('HOD', 'الميناء', 'Al Mina', 'HOD-02', 14.8050, 42.9200),
  ('HOD', 'باجل', 'Bajil', 'HOD-03', 14.9200, 43.2900)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 3. SAMPLE HEALTH FACILITIES
-- ============================================================
INSERT INTO health_facilities (district_id, name_ar, name_en, code, facility_type)
SELECT dist.id, f.name_ar, f.name_en, f.code, f.facility_type
FROM (VALUES
  ('SAN-01', 'مستشفى الثورة', 'Al Thawra Hospital', 'SAN-01-H01', 'hospital'),
  ('SAN-01', 'مركز صحي الوحدة', 'Al Wahda Health Center', 'SAN-01-C01', 'health_center'),
  ('SAN-02', 'مركز صحي السبعين', 'Al Sabaeen Health Center', 'SAN-02-C01', 'health_center'),
  ('ADE-01', 'مستشفى كودر', 'Kooder Hospital', 'ADE-01-H01', 'hospital'),
  ('ADE-02', 'مستشفى الجمهورية', 'Republic Hospital', 'ADE-02-H01', 'hospital'),
  ('TAZ-01', 'مستشفى الثورة', 'Revolution Hospital', 'TAZ-01-H01', 'hospital'),
  ('TAZ-01', 'مركز صحي المظفر', 'Al Mudhaffar Health Center', 'TAZ-01-C01', 'health_center')
) AS f(dist_code, name_ar, name_en, code, facility_type)
JOIN districts dist ON dist.code = f.dist_code
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 4. SAMPLE FORM (EPI Vaccination Monitoring)
-- ============================================================
INSERT INTO forms (title_ar, title_en, description_ar, description_en, schema, requires_gps, requires_photo, created_by)
SELECT
  'استمارة مراقبة التطعيم',
  'Vaccination Monitoring Form',
  'استمارة لتتبع ومراقبة حملات التطعيم الميدانية',
  'Form for tracking and monitoring field vaccination campaigns',
  '{
    "type": "object",
    "properties": {
      "vaccination_date": {"type": "string", "format": "date", "title": "تاريخ التطعيم", "required": true},
      "target_children": {"type": "number", "title": "عدد الأطفال المستهدفين", "minimum": 0},
      "vaccinated_children": {"type": "number", "title": "عدد الأطفال المطعمين", "minimum": 0},
      "vaccine_type": {"type": "string", "title": "نوع اللقاح", "enum": ["BCG", "DPT", "OPV", " measles", "Hepatitis B", "Penta"]},
      "team_members": {"type": "number", "title": "أعضاء الفريق", "minimum": 1},
      "supervisor_notes": {"type": "string", "title": "ملاحظات المشرف", "maxLength": 500}
    }
  }'::jsonb,
  true,
  true,
  NULL
WHERE NOT EXISTS (SELECT 1 FROM forms WHERE title_ar = 'استمارة مراقبة التطعيم');

-- ============================================================
-- 5. SAMPLE FORM — Supply Shortage Report
-- ============================================================
INSERT INTO forms (title_ar, title_en, description_ar, description_en, schema, requires_gps, requires_photo, created_by)
SELECT
  'تقرير نقص التجهيزات',
  'Supply Shortage Report',
  'للإبلاغ عن نقص في التجهيزات الطبية واللقاحات',
  'Report medical supply and vaccine shortages',
  '{
    "type": "object",
    "properties": {
      "item_name": {"type": "string", "title": "اسم المادة", "required": true},
      "item_category": {"type": "string", "title": "الفئة", "enum": ["لقاح", "مستلزمات طعيم", "أجهزة", "مواد تعقيم"]},
      "quantity_needed": {"type": "number", "title": "الكمية المطلوبة", "minimum": 1},
      "quantity_available": {"type": "number", "title": "الكمية المتوفرة", "minimum": 0},
      "severity": {"type": "string", "title": "مستوى الخطورة", "enum": ["critical", "high", "medium", "low"]},
      "notes": {"type": "string", "title": "تفاصيل إضافية", "maxLength": 1000}
    }
  }'::jsonb,
  true,
  true,
  NULL
WHERE NOT EXISTS (SELECT 1 FROM forms WHERE title_ar = 'تقرير نقص التجهيزات');

COMMIT;
