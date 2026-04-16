-- ============================================================
-- EPI Supervisor — Seed Data v2.0
-- Yemen Governorates + Districts + Health Facilities
-- ⚠️ Run AFTER 001_schema.sql
-- ============================================================

BEGIN;

-- ============================================================
-- GOVERNORATES (22 Yemeni Governorates)
-- ============================================================
INSERT INTO governorates (name_ar, name_en, code, center_lat, center_lng, population) VALUES
  ('صنعاء', 'Sana''a', 'SA', 15.3694, 44.1910, 3291000),
  ('عدن', 'Aden', 'AD', 12.7855, 45.0189, 860000),
  ('تعز', 'Taiz', 'TA', 13.5794, 44.0211, 2910000),
  ('الحديدة', 'Al Hudaydah', 'HU', 14.7971, 42.9545, 3050000),
  ('إب', 'Ibb', 'IB', 13.9667, 44.1833, 2630000),
  ('ذمار', 'Dhamar', 'DH', 14.5583, 44.4116, 1750000),
  ('حضرموت', 'Hadramaut', 'HA', 15.9590, 48.7900, 1260000),
  ('المهرة', 'Al Mahrah', 'MA', 15.1667, 51.2500, 400000),
  ('الجوف', 'Al Jawf', 'JA', 16.7890, 45.5960, 660000),
  ('مأرب', 'Marib', 'MR', 15.4694, 45.3264, 530000),
  ('البيضاء', 'Al Bayda', 'BA', 14.3558, 45.3286, 820000),
  ('الضالع', 'Al Dhale''e', 'DL', 13.6958, 44.7314, 620000),
  ('لحج', 'Lahij', 'LH', 13.0567, 44.8819, 950000),
  ('أبين', 'Abyan', 'AB', 13.6167, 45.8333, 640000),
  ('شبوة', 'Shabwah', 'SH', 14.5294, 46.8300, 650000),
  ('ريمة', 'Raymah', 'RY', 14.6278, 43.7111, 530000),
  ('عمران', 'Amran', 'AM', 15.6594, 43.9439, 1100000),
  ('صعدة', 'Sa''adah', 'SD', 16.9400, 43.7644, 830000),
  ('حجة', 'Hajjah', 'HJ', 15.6917, 43.6022, 1950000),
  ('المحويت', 'Al Mahwit', 'MW', 15.4711, 43.5464, 670000),
  ('سقطرى', 'Socotra', 'SO', 12.4634, 53.8236, 60000),
  ('أرخبيل سقطرى', 'Socotra Archipelago', 'SOC', 12.2900, 54.0100, 44000)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- DISTRICTS (Key districts per governorate)
-- ============================================================

-- ═══ صنعاء ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('SA', 'الوحدة', 'Al Wahda', 'SA-01', 15.3547, 44.2068),
  ('SA', 'السبعين', 'Al Sabaeen', 'SA-02', 15.3724, 44.1837),
  ('SA', 'معين', 'Ma''ain', 'SA-03', 15.3913, 44.2144),
  ('SA', 'التحرير', 'Al Tahrir', 'SA-04', 15.3481, 44.1911),
  ('SA', 'الصافية', 'Al Safiah', 'SA-05', 15.3234, 44.1589),
  ('SA', 'الروضة', 'Al Rawda', 'SA-06', 15.4012, 44.2267),
  ('SA', 'بني مطر', 'Bani Matar', 'SA-07', 15.4156, 44.0892),
  ('SA', 'الحصن', 'Al Husn', 'SA-08', 15.2987, 44.2534),
  ('SA', 'خولان', 'Kholan', 'SA-09', 15.2654, 44.3012),
  ('SA', 'نهم', 'Nihm', 'SA-10', 15.5023, 44.4567)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ عدن ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('AD', 'كريتر', 'Crater', 'AD-01', 12.7767, 45.0321),
  ('AD', 'المعلا', 'Al Mualla', 'AD-02', 12.7889, 44.9876),
  ('AD', 'التواهي', 'Al Tawahi', 'AD-03', 12.7912, 44.9654),
  ('AD', 'المنصورة', 'Al Mansura', 'AD-04', 12.8034, 45.0012),
  ('AD', 'دار سعد', 'Dar Saad', 'AD-05', 12.8234, 45.0345),
  ('AD', 'الشيخ عثمان', 'Al Sheikh Othman', 'AD-06', 12.8456, 45.0567),
  ('AD', 'البريقة', 'Al Buraiqah', 'AD-07', 12.8123, 44.9234),
  ('AD', 'خور مكسر', 'Khormaksar', 'AD-08', 12.8234, 44.9567)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ تعز ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('TA', 'المظفر', 'Al Mudhaffar', 'TA-01', 13.5789, 44.0211),
  ('TA', 'القاهرة', 'Al Qahira', 'TA-02', 13.5634, 44.0089),
  ('TA', 'صالة', 'Sala', 'TA-03', 13.5923, 44.0345),
  ('TA', 'المصايب', 'Al Masabih', 'TA-04', 13.5456, 44.0567),
  ('TA', 'الشرف', 'Al Sharaf', 'TA-05', 13.6123, 43.9876),
  ('TA', 'صبر الموادم', 'Sabr Al Mawadim', 'TA-06', 13.5012, 44.0890),
  ('TA', 'موزع', 'Mawza', 'TA-07', 13.4234, 44.1234),
  ('TA', 'الصلو', 'Al Salo', 'TA-08', 13.4567, 44.0567),
  ('TA', 'المسراخ', 'Al Misrakh', 'TA-09', 13.6234, 44.0890),
  ('TA', 'شراز', 'Sharaz', 'TA-10', 13.6567, 44.0234)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ الحديدة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('HU', 'الحالي', 'Al Hali', 'HU-01', 14.7971, 42.9545),
  ('HU', 'الميناء', 'Al Mina', 'HU-02', 14.8123, 42.9234),
  ('HU', 'الحوك', 'Al Hawak', 'HU-03', 14.7845, 42.9876),
  ('HU', 'باجل', 'Bajil', 'HU-04', 14.9234, 43.1234),
  ('HU', 'زبيد', 'Zabid', 'HU-05', 14.1978, 43.3123),
  ('HU', 'اللُحية', 'Al Luhayyah', 'HU-06', 15.3456, 42.7890),
  ('HU', 'الخوخة', 'Al Khawkhah', 'HU-07', 14.5678, 43.2345),
  ('HU', 'التحيتا', 'Al Tahita', 'HU-08', 14.0123, 43.3456),
  ('HU', 'حيس', 'Hays', 'HU-09', 14.3456, 43.0123),
  ('HU', 'الجراحي', 'Al Jarrahi', 'HU-10', 14.5678, 43.4567)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ إب ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('IB', 'المشنة', 'Al Masha', 'IB-01', 13.9667, 44.1833),
  ('IB', 'الظهار', 'Al Dhahar', 'IB-02', 13.9456, 44.1567),
  ('IB', 'المذيخرة', 'Al Mudhaykhirah', 'IB-03', 13.8234, 44.2345),
  ('IB', 'يريم', 'Yarim', 'IB-04', 14.2972, 44.3789),
  ('IB', 'الرُضمة', 'Al Radmah', 'IB-05', 14.1234, 44.0123),
  ('IB', 'حبيش', 'Habish', 'IB-06', 14.0567, 44.3456),
  ('IB', 'بعدان', 'Ba''adan', 'IB-07', 13.8890, 44.0567),
  ('IB', 'السدة', 'Al Saddah', 'IB-08', 14.1234, 44.4567)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ ذمار ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('DH', 'المخلاف', 'Al Makhlaf', 'DH-01', 14.5583, 44.4116),
  ('DH', 'عنس', 'Ans', 'DH-02', 14.4234, 44.5678),
  ('DH', 'العتمة', 'Al Atmah', 'DH-03', 14.6234, 44.2345),
  ('DH', 'جهران', 'Jahran', 'DH-04', 14.7890, 44.3456),
  ('DH', 'ميتم', 'Maytam', 'DH-05', 14.3456, 44.6789),
  ('DH', 'الحداء', 'Al Hada', 'DH-06', 14.5678, 44.0123)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ حضرموت ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('HA', 'الوادي', 'Al Wadi', 'HA-01', 15.9590, 48.7900),
  ('HA', 'السحر', 'Al Sahar', 'HA-02', 15.8234, 48.5678),
  ('HA', 'الشحر', 'Al Shahr', 'HA-03', 14.8234, 49.3456),
  ('HA', 'سيئون', 'Seiyun', 'HA-04', 15.9456, 48.7234),
  ('HA', 'تريم', 'Tarim', 'HA-05', 16.0567, 48.9876),
  ('HA', 'القطن', 'Al Qatn', 'HA-06', 15.8890, 48.2345),
  ('HA', 'دوعن', 'Daw''an', 'HA-07', 15.3456, 48.0123),
  ('HA', 'المكلا', 'Al Mukalla', 'HA-08', 14.5417, 49.1278)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ المهرة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('MA', 'الغيضة', 'Al Ghaydah', 'MA-01', 16.2100, 52.1700),
  ('MA', 'حوف', 'Hawf', 'MA-02', 16.6234, 52.8900),
  ('MA', 'قشن', 'Qishn', 'MA-03', 15.4234, 51.6789),
  ('MA', 'المسيلة', 'Al Masilah', 'MA-04', 15.8900, 51.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ الجوف ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('JA', 'الحزم', 'Al Hazm', 'JA-01', 16.7890, 45.5960),
  ('JA', 'الغيل', 'Al Ghayl', 'JA-02', 16.5678, 45.2345),
  ('JA', 'برط العنان', 'Bart Al Anan', 'JA-03', 16.3456, 45.8900),
  ('JA', 'متنة', 'Matammah', 'JA-04', 16.9234, 45.3456),
  ('JA', 'خب والشعف', 'Khabb Wa Al Sha''f', 'JA-05', 16.1234, 45.6789)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ مأرب ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('MR', 'مأرب', 'Marib', 'MR-01', 15.4694, 45.3264),
  ('MR', 'مدغل', 'Madghal', 'MR-02', 15.6234, 45.1234),
  ('MR', 'الجوبة', 'Al Jubah', 'MR-03', 15.2345, 45.5678),
  ('MR', 'رحبة', 'Rahabah', 'MR-04', 15.8900, 45.0123),
  ('MR', 'حريب', 'Harib', 'MR-05', 14.8900, 45.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ البيضاء ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('BA', 'البيضاء', 'Al Bayda', 'BA-01', 14.3558, 45.3286),
  ('BA', 'رداع', 'Rada', 'BA-02', 14.4234, 45.1234),
  ('BA', 'الزاهر', 'Al Zahir', 'BA-03', 14.1234, 45.5678),
  ('BA', 'الصومعة', 'Al Sawma''ah', 'BA-04', 14.6789, 45.0123),
  ('BA', 'نطع', 'Nati''', 'BA-05', 14.2345, 45.7890)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ الضالع ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('DL', 'الضالع', 'Al Dhale''e', 'DL-01', 13.6958, 44.7314),
  ('DL', 'دمت', 'Damta', 'DL-02', 13.5678, 44.8900),
  ('DL', 'الحصين', 'Al Husayn', 'DL-03', 13.8234, 44.5678),
  ('DL', 'جحاف', 'Jahaf', 'DL-04', 13.4567, 44.6789),
  ('DL', 'الشعيبي', 'Al Shu''aybi', 'DL-05', 13.7890, 44.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ لحج ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('LH', 'لحج', 'Lahij', 'LH-01', 13.0567, 44.8819),
  ('LH', 'الحوطة', 'Al Hawtah', 'LH-02', 13.1234, 44.6789),
  ('LH', 'تبن', 'Tuban', 'LH-03', 13.2345, 45.0123),
  ('LH', 'المضاربة', 'Al Mudarribah', 'LH-04', 12.8900, 44.7890),
  ('LH', 'يريم', 'Yarim', 'LH-05', 13.3456, 44.5678),
  ('LH', 'ردفان', 'Radfan', 'LH-06', 13.4567, 44.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ أبين ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('AB', 'زنجبار', 'Zinjibar', 'AB-01', 13.1289, 45.3801),
  ('AB', 'جعار', 'Ja''ar', 'AB-02', 13.2234, 45.3123),
  ('AB', 'خنفر', 'Khanfar', 'AB-03', 13.3456, 45.5678),
  ('AB', 'مودية', 'Mudiyah', 'AB-04', 13.5678, 45.0123),
  ('AB', 'لودر', 'Lawdar', 'AB-05', 13.7890, 45.8900)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ شبوة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('SH', 'عتق', 'Ataq', 'SH-01', 14.5294, 46.8300),
  ('SH', 'بيحان', 'Bayhan', 'SH-02', 14.7890, 46.5678),
  ('SH', 'عين', 'Ain', 'SH-03', 14.3456, 47.0123),
  ('SH', 'ميفعة', 'Mayfa''ah', 'SH-04', 14.1234, 46.6789),
  ('SH', 'رصد', 'Rasad', 'SH-05', 14.8900, 47.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ ريمة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('RY', 'الجبين', 'Al Jabin', 'RY-01', 14.6278, 43.7111),
  ('RY', 'بلاد الطعام', 'Bilad At Ta''am', 'RY-02', 14.5678, 43.5678),
  ('RY', 'كسمة', 'Kusmah', 'RY-03', 14.4567, 43.8900),
  ('RY', 'السلفية', 'Al Salafiyah', 'RY-04', 14.7890, 43.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ عمران ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('AM', 'عمران', 'Amran', 'AM-01', 15.6594, 43.9439),
  ('AM', 'السودة', 'Al Sawdah', 'AM-02', 15.7890, 43.7890),
  ('AM', 'خارف', 'Kharif', 'AM-03', 15.5678, 44.1234),
  ('AM', 'المحابشة', 'Al Mahabishah', 'AM-04', 15.8900, 43.5678),
  ('AM', 'مسور', 'Maswar', 'AM-05', 15.3456, 44.2345),
  ('AM', 'ريدة', 'Raydah', 'AM-06', 15.4567, 43.8900)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ صعدة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('SD', 'صعدة', 'Sa''adah', 'SD-01', 16.9400, 43.7644),
  ('SD', 'حيدان', 'Haydan', 'SD-02', 16.7890, 43.5678),
  ('SD', 'قطابر', 'Qatabar', 'SD-03', 17.1234, 43.8900),
  ('SD', 'الصفراء', 'Al Safra', 'SD-04', 16.5678, 44.0123),
  ('SD', 'مجز', 'Majz', 'SD-05', 16.3456, 43.4567),
  ('SD', 'الصميل', 'Al Sumil', 'SD-06', 17.2345, 43.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ حجة ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('HJ', 'حجة', 'Hajjah', 'HJ-01', 15.6917, 43.6022),
  ('HJ', 'حيران', 'Hiran', 'HJ-02', 15.8900, 43.4567),
  ('HJ', 'كُحلان', 'Kuhlan', 'HJ-03', 15.5678, 43.7890),
  ('HJ', 'عبس', 'Abs', 'HJ-04', 15.9234, 43.2345),
  ('HJ', 'المفتاح', 'Al Miftah', 'HJ-05', 15.3456, 43.8900),
  ('HJ', 'الجميمة', 'Al Jamimah', 'HJ-06', 15.7890, 43.0123),
  ('HJ', 'مستباء', 'Mastabah', 'HJ-07', 16.0123, 43.3456)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ المحويت ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('MW', 'المحويت', 'Al Mahwit', 'MW-01', 15.4711, 43.5464),
  ('MW', 'الخبت', 'Al Khabt', 'MW-02', 15.3456, 43.6789),
  ('MW', 'بني سعد', 'Bani Sa''d', 'MW-03', 15.5678, 43.3456),
  ('MW', 'ملحان', 'Milhan', 'MW-04', 15.2345, 43.7890)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ═══ سقطرى ═══
INSERT INTO districts (governorate_id, name_ar, name_en, code, center_lat, center_lng)
SELECT g.id, d.name_ar, d.name_en, d.code, d.center_lat, d.center_lng
FROM (VALUES
  ('SO', 'حديبو', 'Hadiboh', 'SO-01', 12.6486, 54.0185),
  ('SO', 'قلنسية', 'Qalansiyah', 'SO-02', 12.6890, 53.4567)
) AS d(gov_code, name_ar, name_en, code, center_lat, center_lng)
JOIN governorates g ON g.code = d.gov_code
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- HEALTH FACILITIES (Sample facilities per district)
-- ============================================================

-- صنعاء
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('SA-01', 'مستشفى الثورة', 'Al Thawrah Hospital', 'hospital', 15.3520, 44.2050, 200),
  ('SA-01', 'مركز صحي الوحدة', 'Al Wahda Health Center', 'health_center', 15.3560, 44.2080, 30),
  ('SA-02', 'مستشفى السبعين', 'Al Sabaeen Hospital', 'hospital', 15.3710, 44.1820, 150),
  ('SA-02', 'مركز صحي السبعين', 'Al Sabaeen Health Center', 'health_center', 15.3730, 44.1850, 25),
  ('SA-03', 'مركز صحي معين', 'Ma''ain Health Center', 'health_center', 15.3900, 44.2130, 20),
  ('SA-04', 'مستشفى التحرير', 'Al Tahrir Hospital', 'hospital', 15.3470, 44.1900, 180),
  ('SA-05', 'مركز صحي الصافية', 'Al Safiah Health Center', 'health_center', 15.3220, 44.1570, 20),
  ('SA-06', 'مركز صحي الروضة', 'Al Rawda Health Center', 'health_center', 15.4000, 44.2250, 25)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- عدن
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('AD-01', 'مستشفى كريتر', 'Crater Hospital', 'hospital', 12.7750, 45.0300, 250),
  ('AD-01', 'مركز صحي كريتر', 'Crater Health Center', 'health_center', 12.7780, 45.0340, 30),
  ('AD-02', 'مستشفى المعلا', 'Al Mualla Hospital', 'hospital', 12.7870, 44.9860, 300),
  ('AD-03', 'مركز صحي التواهي', 'Al Tawahi Health Center', 'health_center', 12.7900, 44.9640, 25),
  ('AD-04', 'مركز صحي المنصورة', 'Al Mansura Health Center', 'health_center', 12.8020, 45.0000, 20),
  ('AD-05', 'مركز صحي دار سعد', 'Dar Saad Health Center', 'health_center', 12.8220, 45.0330, 30),
  ('AD-06', 'مستشفى الشيخ عثمان', 'Al Sheikh Othman Hospital', 'hospital', 12.8440, 45.0550, 180),
  ('AD-08', 'مركز صحي خور مكسر', 'Khormaksar Health Center', 'health_center', 12.8220, 44.9550, 25)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- تعز
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('TA-01', 'مستشفى المظفر', 'Al Mudhaffar Hospital', 'hospital', 13.5770, 44.0190, 350),
  ('TA-01', 'مركز صحي المظفر', 'Al Mudhaffar Health Center', 'health_center', 13.5800, 44.0230, 30),
  ('TA-02', 'مستشفى الجمهورية', 'Republic Hospital', 'hospital', 13.5620, 44.0070, 400),
  ('TA-03', 'مركز صحي صالة', 'Sala Health Center', 'health_center', 13.5910, 44.0330, 25),
  ('TA-04', 'مركز صحي المصايب', 'Al Masabih Health Center', 'health_center', 13.5440, 44.0550, 20),
  ('TA-05', 'مركز صحي الشرف', 'Al Sharaf Health Center', 'health_center', 13.6110, 43.9860, 25)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- الحديدة
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('HU-01', 'مستشفى الثورة', 'Al Thawrah Hospital', 'hospital', 14.7960, 42.9530, 300),
  ('HU-01', 'مركز صحي الحالي', 'Al Hali Health Center', 'health_center', 14.7980, 42.9560, 25),
  ('HU-02', 'مركز صحي الميناء', 'Al Mina Health Center', 'health_center', 14.8110, 42.9220, 30),
  ('HU-03', 'مركز صحي الحوك', 'Al Hawak Health Center', 'health_center', 14.7830, 42.9860, 20),
  ('HU-04', 'مركز صحي باجل', 'Bajil Health Center', 'health_center', 14.9220, 43.1220, 25),
  ('HU-05', 'مركز صحي زبيد', 'Zabid Health Center', 'health_center', 14.1960, 43.3110, 20)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- إب
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('IB-01', 'مستشفى إب العام', 'Ibb General Hospital', 'hospital', 13.9650, 44.1820, 300),
  ('IB-01', 'مركز صحي المشنة', 'Al Masha Health Center', 'health_center', 13.9680, 44.1850, 25),
  ('IB-04', 'مركز صحي يريم', 'Yarim Health Center', 'health_center', 14.2960, 44.3770, 20)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- ذمار
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('DH-01', 'مستشفى ذمار العام', 'Dhamar General Hospital', 'hospital', 14.5570, 44.4100, 250),
  ('DH-01', 'مركز صحي المخلاف', 'Al Makhlaf Health Center', 'health_center', 14.5600, 44.4130, 25),
  ('DH-02', 'مركز صحي عنس', 'Ans Health Center', 'health_center', 14.4220, 44.5660, 20)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

-- حضرموت (المكلا + سيئون)
INSERT INTO health_facilities (district_id, name_ar, name_en, type, latitude, longitude, capacity)
SELECT d.id, f.name_ar, f.name_en, f.type, f.latitude, f.longitude, f.capacity
FROM (VALUES
  ('HA-08', 'مستشفى المكلا العام', 'Al Mukalla General Hospital', 'hospital', 14.5400, 49.1260, 300),
  ('HA-08', 'مركز صحي المكلا', 'Al Mukalla Health Center', 'health_center', 14.5430, 49.1290, 30),
  ('HA-04', 'مستشفى سيئون', 'Seiyun Hospital', 'hospital', 15.9440, 48.7220, 200),
  ('HA-05', 'مركز صحي تريم', 'Tarim Health Center', 'health_center', 16.0550, 48.9860, 20)
) AS f(district_code, name_ar, name_en, type, latitude, longitude, capacity)
JOIN districts d ON d.code = f.district_code
ON CONFLICT DO NOTHING;

COMMIT;
