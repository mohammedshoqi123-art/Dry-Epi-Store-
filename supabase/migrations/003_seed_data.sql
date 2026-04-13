-- ============================================================
-- EPI Supervisor — Seed Data
-- Governorates + Forms (SIA + Polio) + Sample References
-- ============================================================

BEGIN;

-- ============================================================
-- 1. GOVERNORATES (from 002)
-- ============================================================
INSERT INTO governorates (id, name_ar, name_en, code, center_lat, center_lng) VALUES
  (gen_random_uuid(), 'بغداد', 'Baghdad', 'BGD', 33.3152, 44.3661),
  (gen_random_uuid(), 'البصرة', 'Basra', 'BSR', 30.5085, 47.7804),
  (gen_random_uuid(), 'أربيل', 'Erbil', 'ERB', 36.1911, 44.0092),
  (gen_random_uuid(), 'الموصل', 'Mosul', 'MSL', 36.3350, 43.1189),
  (gen_random_uuid(), 'النجف', 'Najaf', 'NJF', 32.0282, 44.3391),
  (gen_random_uuid(), 'كركوك', 'Kirkuk', 'KRK', 35.4681, 44.3922),
  (gen_random_uuid(), 'ذي قار', 'Dhi Qar', 'DQR', 31.0375, 46.2583),
  (gen_random_uuid(), 'الأنبار', 'Anbar', 'ANB', 33.4211, 43.3033),
  (gen_random_uuid(), 'ديالى', 'Diyala', 'DYL', 33.7500, 45.0000),
  (gen_random_uuid(), 'صلاح الدين', 'Saladin', 'SLD', 34.6000, 43.6800),
  (gen_random_uuid(), 'بابل', 'Babylon', 'BBN', 32.4833, 44.4333),
  (gen_random_uuid(), 'كربلاء', 'Karbala', 'KRB', 32.6167, 44.0333),
  (gen_random_uuid(), 'واسط', 'Wasit', 'WST', 32.4500, 45.8333),
  (gen_random_uuid(), 'المثنى', 'Muthanna', 'MTH', 30.5000, 45.5000),
  (gen_random_uuid(), 'القادسية', 'Qadisiyyah', 'QDS', 31.9833, 45.0500),
  (gen_random_uuid(), 'ميسان', 'Maysan', 'MYS', 31.8333, 47.1500),
  (gen_random_uuid(), 'دهوك', 'Duhok', 'DHK', 36.8667, 43.0000),
  (gen_random_uuid(), 'السليمانية', 'Sulaymaniyah', 'SLY', 35.5500, 45.4333),
  (gen_random_uuid(), 'حلبجة', 'Halabja', 'HLB', 35.1833, 45.9833)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. SIA FORMS (from 003)
-- ============================================================
-- ============================================================
-- EPI Supervisor Platform — SIA Forms (النشاط الايصالي التكاملي)
-- Version: 2.0.0
-- ============================================================

BEGIN;

-- Clean duplicates on re-run
DELETE FROM forms WHERE title_ar IN (
  'استمارة الاشراف للنشاط الايصالي التكاملي',
  'استمارة الجاهزية للنشاط الايصالي التكاملي'
) AND deleted_at IS NULL;

-- ============================================================
-- FORM 1: استمارة الاشراف للنشاط الايصالي التكاملي
-- Supervision Form for Integrated SIA
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  gen_random_uuid(),
  'استمارة الاشراف للنشاط الايصالي التكاملي',
  'Integrated SIA Supervision Form',
  'استمارة شاملة للإشراف الميداني على فرق النشاط الايصالي التكاملي',
  'Comprehensive field supervision form for integrated supplementary immunization activity teams',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "health_facility", "type": "text", "label_ar": "المرفق الصحي التابع للفريق", "required": true},
          {"key": "village_name", "type": "text", "label_ar": "اسم القرية التي يعمل بها الفريق", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true},
          {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true}
        ]
      },
      {
        "id": "team_info",
        "title_ar": "معلومات الفريق",
        "order": 2,
        "fields": [
          {"key": "team_members", "type": "textarea", "label_ar": "أسماء أعضاء الفريق", "required": true},
          {"key": "has_activity_plan", "type": "yesno", "label_ar": "هل لدى الفريق خطة وخارطة تبين القرى المستهدفة حسب خط سير الفريق أيام النشاط؟", "required": true},
          {"key": "active_members_count", "type": "number", "label_ar": "أعضاء الفريق العاملين", "required": true},
          {"key": "has_doctor_or_trained", "type": "yesno", "label_ar": "هل أحد أعضاء الفريق طبيب؟ أو فني مدرب على الرعاية التكاملية", "required": true},
          {"key": "wearing_uniform", "type": "yesno", "label_ar": "هل يلتزم أعضاء الفريق بلبس الزي (البالطو)؟", "required": true}
        ]
      },
      {
        "id": "work_environment",
        "title_ar": "بيئة العمل والتنسيق",
        "order": 3,
        "fields": [
          {"key": "suitable_location", "type": "yesno", "label_ar": "هل المكان المختار لتنفيذ الجلسة مناسب ويضمن الخصوصية للنساء؟", "required": true},
          {"key": "community_coordination", "type": "yesno", "label_ar": "هل تم التنسيق المسبق مع المجتمع (تأكد من ذلك في القرية)؟", "required": true},
          {"key": "has_speaker", "type": "yesno", "label_ar": "هل يتوفر مع الفريق مكبر صوت؟", "required": true},
          {"key": "has_transport", "type": "yesno", "label_ar": "هل توجد وسيلة نقل مناسبة لدى الفريق؟", "required": true},
          {"key": "previous_visit", "type": "yesno", "label_ar": "هل تمت زيارة الفريق من قبل المستوى الأعلى ومدونة بسجل الإشراف؟", "required": true}
        ]
      },
      {
        "id": "records_and_docs",
        "title_ar": "السجلات والوثائق",
        "order": 4,
        "fields": [
          {"key": "complete_records", "type": "yesno", "label_ar": "هل تتوفر لدى الفريق سجلات مكتملة بحسب الخدمة؟", "required": true},
          {"key": "daily_work_forms", "type": "yesno", "label_ar": "هل توجد استمارات العمل اليومي حسب الخدمة المقدمة؟", "required": true},
          {"key": "correct_data_entry", "type": "yesno", "label_ar": "هل يتم تدوين البيانات بشكل صحيح وفي المكان المناسب بحسب نوع الخدمة؟", "required": true},
          {"key": "next_visit_noted", "type": "yesno", "label_ar": "هل يتم تدوين العودة للزيارة القادمة؟", "required": true}
        ]
      },
      {
        "id": "vaccination_cards",
        "title_ar": "بطاقات التحصين",
        "order": 5,
        "fields": [
          {"key": "child_vaccination_cards", "type": "yesno", "label_ar": "هل يتم صرف بطاقة تحصين للأطفال المستهدفين للتحصين؟", "required": true},
          {"key": "women_vaccination_cards", "type": "yesno", "label_ar": "هل يتم صرف بطاقة تحصين للنساء المستهدفات للتحصين؟", "required": true}
        ]
      },
      {
        "id": "service_quality",
        "title_ar": "جودة الخدمة",
        "order": 6,
        "fields": [
          {"key": "good_acceptance", "type": "yesno", "label_ar": "هل يوجد إقبال جيد على الخدمة من قبل المستفيدين؟", "required": true},
          {"key": "safe_vaccination", "type": "yesno", "label_ar": "هل يتم ممارسة التطعيم الآمن بشكل صحيح من قبل الفريق؟", "required": true},
          {"key": "respiratory_rate_check", "type": "yesno", "label_ar": "هل يتم احتساب سرعة التنفس للأطفال الذين يعانون من سعال؟", "required": true},
          {"key": "muac_measurement", "type": "yesno", "label_ar": "هل يتم قياس محيط منتصف الذراع للأطفال والنساء بشكل صحيح؟", "required": true},
          {"key": "ors_provision", "type": "yesno", "label_ar": "هل يتم إعطاء محلول الإرواء لكل الأطفال الذين يعانون من إسهال؟", "required": true},
          {"key": "clean_delivery_kit", "type": "yesno", "label_ar": "هل يتم تزويد جميع النساء الحوامل في الشهرين الأخيرين من الحمل بعلبة الولادة النظيفة؟", "required": true},
          {"key": "nutrition_assessment", "type": "yesno", "label_ar": "هل يقوم العامل بتقييم مشاكل التغذية؟", "required": true}
        ]
      },
      {
        "id": "vitamins_and_referral",
        "title_ar": "الفيتامينات والإحالة",
        "order": 7,
        "fields": [
          {"key": "vitamin_a_children", "type": "yesno", "label_ar": "هل يعطي فيتامين (أ) وفق البروتوكول المعتمد للأطفال؟", "required": true},
          {"key": "vitamin_a_women", "type": "yesno", "label_ar": "هل يعطي فيتامين (أ) وفق البروتوكول المعتمد للنساء؟", "required": true},
          {"key": "facility_referral", "type": "yesno", "label_ar": "هل يتم الإحالة للمرفق الصحي؟", "required": true},
          {"key": "correct_medication", "type": "yesno", "label_ar": "هل يتم إعطاء الأدوية بطريقة سليمة ومرشدة؟", "required": true},
          {"key": "nutrition_counseling", "type": "yesno", "label_ar": "هل يقوم العامل الصحي بالنصح والإرشاد حول مشاكل التغذية؟", "required": true}
        ]
      },
      {
        "id": "vaccine_handling",
        "title_ar": "التعامل مع اللقاحات",
        "order": 8,
        "fields": [
          {"key": "vaccine_disposal", "type": "yesno", "label_ar": "هل يتم التخلص من اللقاحات الممزوجة في الفترة المحددة (بعد 6 ساعات من المزج)؟", "required": true},
          {"key": "safety_box_usage", "type": "yesno", "label_ar": "هل يتم استخدام صندوق الأمان بصورة صحيحة والتخلص منه بشكل سليم؟", "required": true},
          {"key": "cold_chain_proper", "type": "yesno", "label_ar": "هل اللقاحات الموجودة في حاملات الطعوم محفوظة بطريقة سليمة؟", "required": true}
        ]
      },
      {
        "id": "supplies_equipment",
        "title_ar": "الإمدادات والمعدات",
        "order": 9,
        "fields": [
          {"key": "family_planning_available", "type": "yesno", "label_ar": "هل توفر وسائل تنظيم الأسرة حسب الأصناف (حبوب مركبة، حبوب إحادية، رفال ذكري، حقن)؟", "required": true},
          {"key": "folic_iron_stock", "type": "yesno", "label_ar": "هل لدى الفريق إمداد كافي من حمض الفوليك والحديد؟", "required": true},
          {"key": "fetal_stethoscope", "type": "yesno", "label_ar": "هل توجد لدى الفريق سماعة جنين؟", "required": true},
          {"key": "bp_device", "type": "yesno", "label_ar": "هل يتوفر لدى الفريق سماعة فحص وجهاز ضغط الدم؟", "required": true},
          {"key": "muac_tape", "type": "yesno", "label_ar": "هل لدى الفريق أشرطة قياس محيط الذراع؟", "required": true},
          {"key": "height_board", "type": "yesno", "label_ar": "هل لدى الفريق أشرطة قياس الطول؟", "required": true},
          {"key": "thermometer", "type": "yesno", "label_ar": "هل لدى الفريق ترمومتر لقياس درجة حرارة الأطفال؟", "required": true},
          {"key": "scale", "type": "yesno", "label_ar": "هل يوجد مع الفريق ميزان؟", "required": true},
          {"key": "daily_supply_tracking", "type": "yesno", "label_ar": "هل يقوم الفريق بتدوين حركة الإمداد الوارد والمنصرف يومياً؟", "required": true}
        ]
      },
      {
        "id": "service_numbers",
        "title_ar": "أعداد المترددين",
        "order": 10,
        "fields": [
          {"key": "immunization_children", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين من الأطفال", "required": true},
          {"key": "immunization_women", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين من النساء", "required": true},
          {"key": "covid19_vaccination", "type": "number", "label_ar": "عدد المترددين لخدمة التحصين بلقاح كوفيد 19", "required": true},
          {"key": "child_health_under2m", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل للأطفال دون الشهرين", "required": true},
          {"key": "child_health_2to59m", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل من 2 إلى 59 شهر", "required": true},
          {"key": "child_health_over5", "type": "number", "label_ar": "عدد المترددين لخدمة صحة الطفل للأطفال فوق الخامسة", "required": true},
          {"key": "fp_clients", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية بتنظيم الأسرة", "required": true},
          {"key": "anc_clients", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية رعاية حوامل", "required": true},
          {"key": "delivery_cases", "type": "number", "label_ar": "عدد المترددين لخدمة الصحة الإنجابية ولادات", "required": true},
          {"key": "nutrition_children_6_59", "type": "number", "label_ar": "عدد المترددين لخدمة التغذية أطفال من 6-59 شهر", "required": true},
          {"key": "referred_children", "type": "number", "label_ar": "الأطفال الذين تم إحالتهم", "required": true},
          {"key": "nutrition_women", "type": "number", "label_ar": "عدد المترددين لخدمة التغذية نساء حوامل ومرضعات", "required": true}
        ]
      },
      {
        "id": "shortages",
        "title_ar": "العجز في الإمدادات",
        "order": 11,
        "fields": [
          {"key": "has_immunization_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة التحصين", "required": true},
          {"key": "immunization_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة التحصين"},
          {"key": "has_covid_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة لقاح كوفيد", "required": true},
          {"key": "covid_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة لقاح كوفيد"},
          {"key": "has_reproductive_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة الصحة الإنجابية", "required": true},
          {"key": "reproductive_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة الصحة الإنجابية"},
          {"key": "has_child_health_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة صحة الطفل", "required": true},
          {"key": "child_health_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة صحة الطفل"},
          {"key": "has_nutrition_shortage", "type": "yesno", "label_ar": "هناك عجز في الإمدادات اللازمة لخدمة التغذية", "required": true},
          {"key": "nutrition_shortage_details", "type": "textarea", "label_ar": "اذكر الإمدادات المنتقصة لخدمة التغذية"}
        ]
      },
      {
        "id": "follow_up",
        "title_ar": "المتابعة والتوصيات",
        "order": 12,
        "fields": [
          {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
          {"key": "actions_taken", "type": "textarea", "label_ar": "الإجراءات المتخذة", "required": true},
          {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
          {"key": "supervision_photo", "type": "photo", "label_ar": "صورة توثيقية للنزول الاشرافي"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      },
      {
        "id": "catch_up_policy",
        "title_ar": "سياسة الالتحاق بالركب",
        "order": 13,
        "fields": [
          {"key": "has_vaccine_carrier", "type": "yesno", "label_ar": "هل لدى المطعم حافظة لقاح مع قوالب ثلج مبردة؟", "required": true},
          {"key": "vaccines_sufficient", "type": "yesno", "label_ar": "هل اللقاحات والمستلزمات الأخرى متوفرة وكافية لجلسة التطعيم؟", "required": true},
          {"key": "correct_vaccine_site", "type": "yesno", "label_ar": "هل يتم إعطاء اللقاح في الموضع المناسب والصحيح؟", "required": true},
          {"key": "catch_up_knowledge", "type": "yesno", "label_ar": "هل لدى العاملين الصحيين معرفة شاملة بسياسة الالتحاق بالركب؟", "required": true},
          {"key": "catch_up_training", "type": "yesno", "label_ar": "هل تلقى العاملين الصحيين التدريب الكافي لتنفيذ سياسة الالتحاق بالركب بفعالية؟", "required": true},
          {"key": "catch_up_2to5_registration", "type": "yesno", "label_ar": "هل يقوم المطعم بالتطعيم للأطفال من 2 إلى 5 سنوات وتسجيل بياناتهم كجزء من استراتيجية الالتحاق بالركب؟", "required": true},
          {"key": "team_target_knowledge", "type": "yesno", "label_ar": "هل لدى الفريق معرفة بالمستهدف الخاص بالنشاط الايصالي التكاملي للمنطقة (أطفال دون العام، من عام إلى عامين، من عامين إلى خمس أعوام)؟", "required": true}
        ]
      },
      {
        "id": "defaulter_tracking",
        "title_ar": "تتبع المتخلفين",
        "order": 14,
        "fields": [
          {"key": "has_defaulter_mechanism", "type": "yesno", "label_ar": "هل يوجد آلية لتتبع المتخلفين؟", "required": true},
          {"key": "defaulter_mechanism_type", "type": "textarea", "label_ar": "ما هي آلية تتبع المتخلفين المتخذة؟"},
          {"key": "has_previous_vaccination_records", "type": "yesno", "label_ar": "هل يوجد مع الفريق سجل التطعيم المستخدم في الجولات السابقة لمتابعة المتخلفين؟", "required": true}
        ]
      },
      {
        "id": "aefi",
        "title_ar": "الآثار الجانبية",
        "order": 15,
        "fields": [
          {"key": "aefi_knowledge", "type": "yesno", "label_ar": "هل لدى العامل الصحي معرفة حول الآثار الجانبية المعتادة (AEFIs) مثل الحمى أو الألم بعد الحقن؟", "required": true},
          {"key": "aefi_mothers_info", "type": "yesno", "label_ar": "هل يقدم المطعم معلومات للأمهات حول الآثار الجانبية المعتادة (AEFIs)؟", "required": true}
        ]
      }
    ]
  }'::jsonb,
  true,
  true,
  true,
 5
);

-- ============================================================
-- FORM 2: استمارة الجاهزية للنشاط الايصالي
-- Readiness Form for Integrated SIA
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  gen_random_uuid(),
  'استمارة الجاهزية للنشاط الايصالي التكاملي',
  'Integrated SIA Readiness Form',
  'استمارة تقييم جاهزية المحافظة لتنفيذ النشاط الايصالي التكاملي',
  'Form for assessing governorate readiness to implement integrated supplementary immunization activity',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف طبي", "رئيس فريق"], "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
        ]
      },
      {
        "id": "readiness_checklist",
        "title_ar": "قائمة تقييم الجاهزية",
        "order": 2,
        "fields": [
          {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية المالية؟", "required": true},
          {"key": "routine_vaccines_available", "type": "yesno", "label_ar": "توفر اللقاحات الروتينية", "required": true},
          {"key": "covid_vaccine_available", "type": "yesno", "label_ar": "توفر لقاح كوفيد", "required": true},
          {"key": "medicines_available", "type": "yesno", "label_ar": "توفر الأدوية", "required": true},
          {"key": "reproductive_supplies_available", "type": "yesno", "label_ar": "توفر مستلزمات الصحة الإنجابية", "required": true},
          {"key": "staff_available", "type": "yesno", "label_ar": "توفر الكادر الصحي", "required": true},
          {"key": "preparatory_meeting_held", "type": "yesno", "label_ar": "هل تم الاجتماع التحضيري للحملة؟", "required": true},
          {"key": "meeting_date", "type": "date", "label_ar": "تاريخ الاجتماع التحضيري"},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي"}
        ]
      },
      {
        "id": "launch_status",
        "title_ar": "حالة التدشين",
        "order": 3,
        "fields": [
          {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة في حالة جاهزية للتدشين؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true},
          {"key": "postponement_reasons", "type": "textarea", "label_ar": "اذكر أسباب التأجيل"},
          {"key": "postponed_launch_date", "type": "date", "label_ar": "تاريخ التدشين المؤجل"}
        ]
      },
      {
        "id": "notes",
        "title_ar": "ملاحظات ومتابعة",
        "order": 4,
        "fields": [
          {"key": "notes", "type": "textarea", "label_ar": "ملاحظات"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true,
  true,
  false,
  0
);

COMMIT;

-- ============================================================
-- 3. POLIO FORMS (from 004)
-- ============================================================
-- ============================================================
-- EPI Supervisor Platform — Polio Campaign Forms
-- حملة شلل الأطفال
-- Version: 2.0.0
-- ============================================================

BEGIN;

-- Clean duplicates on re-run
DELETE FROM forms WHERE title_ar IN (
  'استمارة جاهزية حملة شلل الأطفال',
  'استمارة الاشراف لحملة شلل الأطفال',
  'استمارة المسح العشوائي لحملة شلل الأطفال'
) AND deleted_at IS NULL;

-- ============================================================
-- FORM 1: استمارة جاهزية حملة الشلل
-- Polio Campaign Readiness Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  gen_random_uuid(),
  'استمارة جاهزية حملة شلل الأطفال',
  'Polio Campaign Readiness Form',
  'استمارة تقييم جاهزية المحافظة لتنفيذ حملة شلل الأطفال',
  'Form for assessing governorate readiness for polio campaign implementation',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_title", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف ميداني", "رئيس فريق"], "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة", "required": true}
        ]
      },
      {
        "id": "budget_supplies",
        "title_ar": "الميزانية والمستلزمات",
        "order": 2,
        "fields": [
          {"key": "budget_received", "type": "yesno", "label_ar": "هل تم استلام الميزانية المالية؟", "required": true},
          {"key": "vaccines_distributed", "type": "yesno", "label_ar": "هل تم إمداد اللقاحات للمديريات؟", "required": true},
          {"key": "iiv_materials_distributed", "type": "yesno", "label_ar": "هل تم إمداد المواد التثقيفية للمديريات؟", "required": true}
        ]
      },
      {
        "id": "health_education",
        "title_ar": "التثقيف الصحي",
        "order": 3,
        "fields": [
          {"key": "he_started", "type": "yesno", "label_ar": "هل تم البدء بأنشطة التثقيف الصحي؟", "required": true},
          {"key": "he_start_date", "type": "date", "label_ar": "تاريخ بدء أنشطة التثقيف الصحي"}
        ]
      },
      {
        "id": "coordination",
        "title_ar": "الاجتماع التحضيري",
        "order": 4,
        "fields": [
          {"key": "preparatory_meeting_held", "type": "yesno", "label_ar": "هل تم الاجتماع التحضيري للحملة؟", "required": true},
          {"key": "meeting_date", "type": "date", "label_ar": "تاريخ الاجتماع التحضيري"}
        ]
      },
      {
        "id": "training",
        "title_ar": "التدريب",
        "order": 5,
        "fields": [
          {"key": "training_started", "type": "yesno", "label_ar": "هل تم البدء بعملية التدريب؟", "required": true},
          {"key": "training_quality", "type": "select", "label_ar": "جودة التدريب", "options": ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"], "required": true},
          {"key": "training_date", "type": "date", "label_ar": "تاريخ التدريب"},
          {"key": "training_pros_cons", "type": "textarea", "label_ar": "الإيجابيات والسلبيات لعملية التدريب"}
        ]
      },
      {
        "id": "launch_status",
        "title_ar": "حالة التدشين",
        "order": 6,
        "fields": [
          {"key": "ready_for_launch", "type": "select", "label_ar": "هل المحافظة في حالة جاهزية للتدشين؟", "options": ["جاهزة", "غير جاهزة", "جاهزة جزئياً"], "required": true},
          {"key": "postponement_reasons", "type": "textarea", "label_ar": "اذكر أسباب التأجيل"},
          {"key": "postponed_launch_date", "type": "date", "label_ar": "تاريخ التدشين المؤجل"}
        ]
      },
      {
        "id": "signature",
        "title_ar": "التوقيع",
        "order": 7,
        "fields": [
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ============================================================
-- FORM 2: استمارة الاشراف لحملة الشلل
-- Polio Campaign Supervision Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  gen_random_uuid(),
  'استمارة الاشراف لحملة شلل الأطفال',
  'Polio Campaign Supervision Form',
  'استمارة شاملة للإشراف الميداني على فرق حملة شلل الأطفال',
  'Comprehensive field supervision form for polio campaign teams',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_level", "type": "select", "label_ar": "المستوى", "options": ["مستوى أول", "مستوى ثاني", "مستوى ثالث", "مستوى رابع"], "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "health_facility", "type": "text", "label_ar": "المرفق الصحي التابع للفريق", "required": true},
          {"key": "village_name", "type": "text", "label_ar": "اسم القرية التي يعمل بها الفريق", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "team_number", "type": "number", "label_ar": "رقم الفريق", "required": true},
          {"key": "team_type", "type": "select", "label_ar": "نوع الفريق", "options": ["فريق ثابت", "فريق متحرك", "فريق مشترك"], "required": true},
          {"key": "team_members_count", "type": "number", "label_ar": "عدد أعضاء الفريق", "required": true},
          {"key": "trained_members_count", "type": "number", "label_ar": "عدد المدربين منهم", "required": true},
          {"key": "team_members_names", "type": "textarea", "label_ar": "أسماء أعضاء الفريق", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true}
        ]
      },
      {
        "id": "team_presence",
        "title_ar": "تواجد الفريق",
        "order": 2,
        "fields": [
          {"key": "vaccinators_count", "type": "number", "label_ar": "عدد المطعمين وقت الزيارة", "required": true},
          {"key": "both_members_present", "type": "yesno", "label_ar": "هل عنصري الفريق متواجدين وقت الزيارة؟", "required": true},
          {"key": "has_female_member", "type": "yesno", "label_ar": "هل توجد امرأة عضو في الفريق؟", "required": true},
          {"key": "local_member", "type": "yesno", "label_ar": "هل يوجد عضو في الفريق من نفس المنطقة؟", "required": true},
          {"key": "has_id_cards", "type": "yesno", "label_ar": "هل لدى الفريق كروت تعريف؟", "required": true}
        ]
      },
      {
        "id": "work_plan",
        "title_ar": "خطة العمل والتنقل",
        "order": 3,
        "fields": [
          {"key": "has_daily_route_map", "type": "yesno", "label_ar": "هل توجد لدى الفريق خطة لخط سير للعمل اليوم موضحة برسم كروكي؟", "required": true},
          {"key": "can_locate_on_map", "type": "yesno", "label_ar": "هل يستطيع الفريق تحديد مكانه على الخارطة؟", "required": true},
          {"key": "mobile_team_h2h", "type": "yesno", "label_ar": "هل يقوم الفريق المتحرك بالتنقل من منزل إلى منزل بحسب خطة السير؟", "required": true},
          {"key": "personal_contact_rules", "type": "yesno", "label_ar": "هل يطبق الفريق قواعد الاتصال الشخصي؟", "required": true}
        ]
      },
      {
        "id": "vaccination_practice",
        "title_ar": "ممارسة التطعيم",
        "order": 4,
        "fields": [
          {"key": "asks_all_under5", "type": "yesno", "label_ar": "هل يسأل الفريق على جميع الأطفال دون الخامسة والمتغيبين؟", "required": true},
          {"key": "correct_drops_45deg", "type": "yesno", "label_ar": "هل يقوم الفريق بإعطاء قطرتين من اللقاح وبزاوية 45 درجة بطريقة صحيحة؟", "required": true},
          {"key": "confirms_swallowing", "type": "yesno", "label_ar": "هل يتم التأكد من قبل الفريق من بلع الطفل للقاح؟", "required": true},
          {"key": "correct_daily_register", "type": "yesno", "label_ar": "هل يتم تسجيل بيانات الأطفال المطعمين والمتغيبين والرافضين في دفتر الإحصاء اليومي بالشكل الصحيح؟", "required": true},
          {"key": "follows_defaulters", "type": "yesno", "label_ar": "هل يتم متابعة المتغيبين والعودة لتطعيمهم؟", "required": true},
          {"key": "marks_fingers_correctly", "type": "yesno", "label_ar": "هل يقوم الفريق بتعليم أصابع الأطفال المطعمين بطريقة صحيحة؟", "required": true},
          {"key": "marks_houses_correctly", "type": "yesno", "label_ar": "هل يقوم الفريق بوضع العلامات على المنازل بطريقة صحيحة؟", "required": true}
        ]
      },
      {
        "id": "supplies",
        "title_ar": "المستلزمات واللقاحات",
        "order": 5,
        "fields": [
          {"key": "has_sufficient_supplies", "type": "yesno", "label_ar": "هل يوجد مع الفريق التموين الكافي من المستلزمات (دفتر الإحصاء الاسمي/طباشير/قلم علامة)؟", "required": true},
          {"key": "sufficient_vials", "type": "yesno", "label_ar": "هل يوجد مع الفريق كمية كافية من لقاح الشلل والقطارات الخاصة به؟", "required": true},
          {"key": "proper_cold_chain", "type": "yesno", "label_ar": "هل قنينات لقاح الشلل محفوظة في كيس حراري داخل الحافظة وبها قوالب باردة؟", "required": true},
          {"key": "understands_vvm", "type": "yesno", "label_ar": "هل يفهم الفريق مؤشر مراقبة اللقاح (VVM)؟", "required": true},
          {"key": "vvm_status_correct", "type": "yesno", "label_ar": "هل مؤشر مراقبة اللقاح في القنينة في الوضع السليم؟", "required": true}
        ]
      },
      {
        "id": "supervision_level",
        "title_ar": "الإشراف الإلكتروني",
        "order": 6,
        "fields": [
          {"key": "uses_electronic_app", "type": "yesno", "label_ar": "هل يستخدم مشرف الفرق التطبيق الالكتروني للإشراف على الفرق؟", "required": true},
          {"key": "daily_team_visit", "type": "yesno", "label_ar": "هل يقوم مشرف الفريق بزيارة الفريق مرة واحدة على الأقل في اليوم؟", "required": true},
          {"key": "guides_and_notes", "type": "yesno", "label_ar": "هل مشرف الفريق يرشد ويوجه الفريق ويدون الملاحظات والتعليمات في استمارة الزيارات؟", "required": true}
        ]
      },
      {
        "id": "surveillance",
        "title_ar": "الترصد الوبائي",
        "order": 7,
        "fields": [
          {"key": "asks_about_aps", "type": "yesno", "label_ar": "هل يسأل العامل الصحي عن وجود حالات شلل مشتبهة (APS)؟", "required": true},
          {"key": "has_ppe", "type": "yesno", "label_ar": "هل تتوفر مع الفريق أدوات الحماية (كمامات - معقم يد)؟", "required": true}
        ]
      },
      {
        "id": "reverse_supply",
        "title_ar": "الإمداد العكسي",
        "order": 8,
        "fields": [
          {"key": "daily_reverse_tracking", "type": "yesno", "label_ar": "هل يتم تسجيل بيانات الإمداد العكسي من قبل مشرف الفريق بشكل يومي ومكتمل؟", "required": true}
        ]
      },
      {
        "id": "waste_management",
        "title_ar": "إدارة النفايات الطبية",
        "order": 9,
        "fields": [
          {"key": "has_sharps_and_waste_bags", "type": "yesno", "label_ar": "هل توجد لدي الفريق كيس التخلص (الأحمر والوردي - قابلان لإعادة الإغلاق والفتح) قيد الاستخدام؟", "required": true},
          {"key": "collects_sharps_immediately", "type": "yesno", "label_ar": "هل يقوم الفريق بجمع الفيالات المستخدمة مع قطاراتها أو الغير صالحة أول بأول وبشكل مباشر للكيس الأحمر؟", "required": true},
          {"key": "collects_masks_immediately", "type": "yesno", "label_ar": "هل يقوم الفريق بجمع الكمامات المستخدمة أول بأول وبشكل مباشر للكيس الوردي؟", "required": true},
          {"key": "correct_bag_labeling", "type": "yesno", "label_ar": "هل تسجل البيانات المطلوبة على الكيس الأحمر والوردي بشكل واضح وصحيح (اليوم/التاريخ/رقم الفريق...الخ)؟", "required": true},
          {"key": "vial_count_matches", "type": "yesno", "label_ar": "هل عدد الفيالات داخل الكيس الأحمر والمتبقي داخل الحافظة اليومية يساوي إجمالي عدد الفيالات المستلمة؟", "required": true},
          {"key": "daily_bag_handover", "type": "yesno", "label_ar": "هل يقوم الفريق نهاية كل يوم عمل بتسليم الكيس الأحمر والوردي لمشرف الفريق؟", "required": true}
        ]
      },
      {
        "id": "challenges",
        "title_ar": "التحديات والتوصيات",
        "order": 10,
        "fields": [
          {"key": "challenges", "type": "textarea", "label_ar": "التحديات والصعوبات", "required": true},
          {"key": "actions_taken", "type": "textarea", "label_ar": "الإجراءات المتخذة", "required": true},
          {"key": "recommendations", "type": "textarea", "label_ar": "التوصيات", "required": true},
          {"key": "supervision_photo", "type": "photo", "label_ar": "صورة توثيقية للنزول الاشرافي"},
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      },
      {
        "id": "vitamin_a",
        "title_ar": "فيتامين أ",
        "order": 11,
        "fields": [
          {"key": "supervisor_title_va", "type": "select", "label_ar": "صفة المشرف", "options": ["مشرف صحي", "مشرف تنسيق", "مشرف ميداني", "رئيس فريق"]},
          {"key": "has_vitamin_a", "type": "yesno", "label_ar": "هل يتوفر فيتامين أ (100 ألف وحدة و 200 ألف وحدة) لدى الفريق؟", "required": true},
          {"key": "correct_vitamin_a_admin", "type": "yesno", "label_ar": "هل يتم إعطاء فيتامين أ للأطفال بشكل صحيح وبحسب الفئات العمرية؟", "required": true},
          {"key": "has_scissors_container", "type": "yesno", "label_ar": "هل يتوفر لدى الفريق مقص وعلبة بلاستيكية لحفظ الفيتامين؟", "required": true}
        ]
      }
    ]
  }'::jsonb,
  true, true, true, 5
);

-- ============================================================
-- FORM 3: استمارة المسح العشوائي لحملة الشلل
-- Polio Campaign Random Survey Form
-- ============================================================

INSERT INTO forms (
  id, title_ar, title_en, description_ar, description_en,
  schema, is_active, requires_gps, requires_photo, max_photos
) VALUES (
  gen_random_uuid(),
  'استمارة المسح العشوائي لحملة شلل الأطفال',
  'Polio Campaign Random Survey Form',
  'استمارة لإجراء مسح عشوائي لتقييم تغطية التطعيم أثناء حملة شلل الأطفال',
  'Form for conducting random survey to assess vaccination coverage during polio campaign',
  '{
    "sections": [
      {
        "id": "general_info",
        "title_ar": "المعلومات العامة",
        "order": 1,
        "fields": [
          {"key": "form_number", "type": "text", "label_ar": "رقم الاستمارة", "required": true},
          {"key": "activity_name", "type": "text", "label_ar": "اسم النشاط", "required": true},
          {"key": "supervision_date", "type": "date", "label_ar": "اليوم", "required": true},
          {"key": "supervisor_name", "type": "text", "label_ar": "اسم المشرف", "required": true},
          {"key": "supervisor_level", "type": "select", "label_ar": "المستوى", "options": ["مستوى أول", "مستوى ثاني", "مستوى ثالث", "مستوى رابع"], "required": true},
          {"key": "supervisor_phone", "type": "phone", "label_ar": "رقم جوال المشرف", "required": true},
          {"key": "governorate_id", "type": "governorate", "label_ar": "المحافظة التي تم الاشراف فيها", "required": true},
          {"key": "district_id", "type": "district", "label_ar": "ال مديرية", "required": true},
          {"key": "sub_district", "type": "text", "label_ar": "العزلة", "required": true},
          {"key": "neighborhood", "type": "text", "label_ar": "الحارة", "required": true},
          {"key": "gps_location", "type": "gps", "label_ar": "الموقع الجغرافي", "required": true},
          {"key": "visit_time", "type": "time", "label_ar": "وقت تنفيذ الزيارة الاشرافية", "required": true}
        ]
      },
      {
        "id": "household_info",
        "title_ar": "بيانات المنزل",
        "order": 2,
        "fields": [
          {"key": "house_number", "type": "text", "label_ar": "رقم المنزل", "required": true},
          {"key": "house_owner_name", "type": "text", "label_ar": "اسم صاحب المنزل", "required": true}
        ]
      },
      {
        "id": "under5_summary",
        "title_ar": "ملخص أطفال دون الخامسة",
        "order": 3,
        "fields": [
          {"key": "total_under5", "type": "number", "label_ar": "إجمالي عدد الأطفال دون الخامسة", "required": true},
          {"key": "vaccinated_under5", "type": "number", "label_ar": "عدد الأطفال المطعمين دون الخامسة", "required": true},
          {"key": "unvaccinated_under5", "type": "number", "label_ar": "عدد الأطفال غير المطعمين دون الخامسة", "required": true}
        ]
      },
      {
        "id": "age_0_11m",
        "title_ar": "الفئة العمرية 0-11 شهر",
        "order": 4,
        "fields": [
          {"key": "total_0_11m", "type": "number", "label_ar": "إجمالي عدد الأطفال من 0-11 شهر", "required": true},
          {"key": "vaccinated_0_11m", "type": "number", "label_ar": "عدد المطعمين منهم من 0-11 شهر", "required": true},
          {"key": "unvaccinated_0_11m", "type": "number", "label_ar": "عدد غير المطعمين من 0-11 شهر", "required": true}
        ]
      },
      {
        "id": "age_12_59m",
        "title_ar": "الفئة العمرية 12-59 شهر",
        "order": 5,
        "fields": [
          {"key": "total_12_59m", "type": "number", "label_ar": "إجمالي عدد الأطفال 12-59 شهر", "required": true},
          {"key": "vaccinated_12_59m", "type": "number", "label_ar": "عدد المطعمين منهم 12-59 شهر", "required": true},
          {"key": "unvaccinated_12_59m", "type": "number", "label_ar": "عدد غير المطعمين 12-59 شهر", "required": true}
        ]
      },
      {
        "id": "refusal_reasons",
        "title_ar": "أسباب عدم التطعيم",
        "order": 6,
        "fields": [
          {"key": "non_vaccination_reasons", "type": "textarea", "label_ar": "أسباب عدم التطعيم"},
          {"key": "refusal_reasons", "type": "textarea", "label_ar": "أسباب الرفض اذكرها"}
        ]
      },
      {
        "id": "house_marking",
        "title_ar": "علامة المنزل",
        "order": 7,
        "fields": [
          {"key": "house_marking", "type": "text", "label_ar": "علامة المنزل"}
        ]
      },
      {
        "id": "supervisor_vaccination",
        "title_ar": "تطعيم بواسطة المشرف",
        "order": 8,
        "fields": [
          {"key": "vaccinated_by_supervisor", "type": "number", "label_ar": "عدد الأطفال المطعمين بواسطة المشرف الزائر (مشرفي الفرق)"}
        ]
      },
      {
        "id": "final",
        "title_ar": "التوقيع",
        "order": 9,
        "fields": [
          {"key": "supervisor_signature", "type": "signature", "label_ar": "التوقيع"}
        ]
      }
    ]
  }'::jsonb,
  true, true, false, 0
);

-- ============================================================
-- END OF POLIO CAMPAIGN FORMS
-- ============================================================

COMMIT;

-- ============================================================
-- 4. SAMPLE REFERENCES
-- ============================================================
INSERT INTO references_table (title_ar, description_ar, category, is_active) VALUES
  ('دليل برنامج التطعيم الموسع', 'الدليل الرسمي لبرنامج EPI شامل لجميع اللقاحات والجداول', 'guide', true),
  ('كتيب النشاط الايصالي التكاملي', 'دليل ميداني لتنفيذ حملات SIA', 'manual', true),
  ('دليل مكافحة شلل الأطفال', 'خطوات الترصد والاستجابة لشلل الأطفال', 'guide', true),
  ('استمارة النواقص - نموذج', 'نموذج استمارة الإبلاغ عن نواقص التجهيزات', 'form', true)
ON CONFLICT DO NOTHING;

COMMIT;
