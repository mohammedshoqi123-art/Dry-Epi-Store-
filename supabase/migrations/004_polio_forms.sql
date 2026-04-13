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
