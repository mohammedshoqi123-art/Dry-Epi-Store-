-- ============================================================
-- EPI Supervisor Platform — Seed Data
-- Version: 2.0.0
-- ⚠️ شغّل هذا الملف بـ service_role_key (يتجاوز RLS)
-- ============================================================

BEGIN;

-- ============================================================
-- Iraqi Governorates (19)
-- ============================================================
INSERT INTO governorates (id, name_ar, name_en, code, center_lat, center_lng) VALUES
  (uuid_generate_v4(), 'بغداد', 'Baghdad', 'BGD', 33.3152, 44.3661),
  (uuid_generate_v4(), 'البصرة', 'Basra', 'BSR', 30.5085, 47.7804),
  (uuid_generate_v4(), 'أربيل', 'Erbil', 'ERB', 36.1911, 44.0092),
  (uuid_generate_v4(), 'الموصل', 'Mosul', 'MSL', 36.3350, 43.1189),
  (uuid_generate_v4(), 'النجف', 'Najaf', 'NJF', 32.0282, 44.3391),
  (uuid_generate_v4(), 'كركوك', 'Kirkuk', 'KRK', 35.4681, 44.3922),
  (uuid_generate_v4(), 'ذي قار', 'Dhi Qar', 'DQR', 31.0375, 46.2583),
  (uuid_generate_v4(), 'الأنبار', 'Anbar', 'ANB', 33.4211, 43.3033),
  (uuid_generate_v4(), 'ديالى', 'Diyala', 'DYL', 33.7500, 45.0000),
  (uuid_generate_v4(), 'صلاح الدين', 'Saladin', 'SLD', 34.6000, 43.6800),
  (uuid_generate_v4(), 'بابل', 'Babylon', 'BBN', 32.4833, 44.4333),
  (uuid_generate_v4(), 'كربلاء', 'Karbala', 'KRB', 32.6167, 44.0333),
  (uuid_generate_v4(), 'واسط', 'Wasit', 'WST', 32.4500, 45.8333),
  (uuid_generate_v4(), 'المثنى', 'Muthanna', 'MTH', 30.5000, 45.5000),
  (uuid_generate_v4(), 'القادسية', 'Qadisiyyah', 'QDS', 31.9833, 45.0500),
  (uuid_generate_v4(), 'ميسان', 'Maysan', 'MYS', 31.8333, 47.1500),
  (uuid_generate_v4(), 'دهوك', 'Duhok', 'DHK', 36.8667, 43.0000),
  (uuid_generate_v4(), 'السليمانية', 'Sulaymaniyah', 'SLY', 35.5500, 45.4333),
  (uuid_generate_v4(), 'حلبجة', 'Halabja', 'HLB', 35.1833, 45.9833)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- Districts — Baghdad
-- ============================================================
INSERT INTO districts (id, governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT uuid_generate_v4(), g.id, d.name_ar, d.name_en, d.code, d.lat, d.lng
FROM governorates g
CROSS JOIN (VALUES
  ('الكرخ', 'Karkh', 'KRK-BGD', 33.3000, 44.3300),
  ('الرصافة', 'Rusafa', 'RSF-BGD', 33.3300, 44.4000),
  ('الصدر', 'Sadr City', 'SDR-BGD', 33.3833, 44.4667),
  ('أبو غريب', 'Abu Ghraib', 'AGB-BGD', 33.2833, 44.1833),
  ('المحمودية', 'Mahmudiya', 'MHM-BGD', 33.0667, 44.3667)
) AS d(name_ar, name_en, code, lat, lng)
WHERE g.code = 'BGD'
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- Districts — Basra
-- ============================================================
INSERT INTO districts (id, governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT uuid_generate_v4(), g.id, d.name_ar, d.name_en, d.code, d.lat, d.lng
FROM governorates g
CROSS JOIN (VALUES
  ('البصرة المركز', 'Basra Center', 'CTR-BSR', 30.5085, 47.7804),
  ('الزبير', 'Zubayr', 'ZBR-BSR', 30.3833, 47.7000),
  ('القرنة', 'Qurna', 'QRN-BSR', 31.0167, 47.4333),
  ('أبو الخصيب', 'Abu Al-Khaseeb', 'AKS-BSR', 30.0500, 48.0167)
) AS d(name_ar, name_en, code, lat, lng)
WHERE g.code = 'BSR'
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- Sample Form
-- ============================================================
INSERT INTO forms (
  title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps
) VALUES (
  'نموذج فحص مراكز التطعيم',
  'Vaccination Center Inspection Form',
  'نموذج لفحص ومتابعة مراكز التطعيم في الميدان',
  'Form for field inspection of vaccination centers',
  '{
    "fields": [
      {"key": "center_name", "type": "text", "label_ar": "اسم المركز", "required": true},
      {"key": "center_type", "type": "select", "label_ar": "نوع المركز", "options": ["رئيسي", "فرعي", "متنقل"], "required": true},
      {"key": "staff_count", "type": "number", "label_ar": "عدد الموظفين", "required": true},
      {"key": "vaccines_available", "type": "multiselect", "label_ar": "اللقاحات المتوفرة", "options": ["BCG", "OPV", "DPT", "Hepatitis B", "Measles", "MMR"]},
      {"key": "cold_chain_status", "type": "select", "label_ar": "حالة سلسلة التبريد", "options": ["ممتاز", "جيد", "يحتاج صيانة", "معطل"], "required": true},
      {"key": "notes", "type": "textarea", "label_ar": "ملاحظات"}
    ]
  }'::jsonb,
  true,
  true
);

COMMIT;
