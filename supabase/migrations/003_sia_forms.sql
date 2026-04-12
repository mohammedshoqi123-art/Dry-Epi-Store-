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
  uuid_generate_v4(),
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
  uuid_generate_v4(),
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
