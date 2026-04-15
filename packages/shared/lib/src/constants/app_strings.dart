/// EPI Supervisor Platform — Arabic String Constants
class AppStrings {
  AppStrings._();

  // ─── App ──────────────────────────────────────────────────────────────────
  static const String appName = "EPI Supervisor's";
  static const String appTagline = 'نظام الإشراف الميداني لحملات التطعيم';

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String login = 'تسجيل الدخول';
  static const String logout = 'تسجيل الخروج';
  static const String email = 'البريد الإلكتروني';
  static const String password = 'كلمة المرور';
  static const String loginSuccess = 'تم تسجيل الدخول بنجاح';
  static const String loginFailed = 'فشل تسجيل الدخول';
  static const String sessionExpired = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى';
  static const String invalidCredentials = 'بريد إلكتروني أو كلمة مرور غير صحيحة';

  // ─── Navigation ───────────────────────────────────────────────────────────
  static const String dashboard = 'الرئيسية';
  static const String forms = 'النماذج';
  static const String submissions = 'الإرساليات';
  static const String map = 'الخريطة';
  static const String analytics = 'التحليلات';
  static const String aiAssistant = 'المساعد الذكي';
  static const String admin = 'الإدارة';
  static const String users = 'المستخدمون';
  static const String auditLogs = 'سجل العمليات';
  static const String settings = 'الإعدادات';
  static const String profile = 'الملف الشخصي';

  // ─── Dashboard ────────────────────────────────────────────────────────────
  static const String welcome = 'مرحباً';
  static const String overallOverview = 'نظرة عامة على المنصة';
  static const String totalSubmissions = 'إجمالي الإرساليات';
  static const String totalShortages = 'إجمالي النواقص';
  static const String criticalShortages = 'النواقص الحرجة';
  static const String resolvedShortages = 'النواقص المحلولة';
  static const String submissionsToday = 'إرساليات اليوم';
  static const String quickActions = 'إجراءات سريعة';
  static const String submissionStatus = 'حالة الإرساليات';

  // ─── Forms ────────────────────────────────────────────────────────────────
  static const String availableForms = 'النماذج المتاحة';
  static const String fillForm = 'تعبئة النموذج';
  static const String saveDraft = 'حفظ كمسودة';
  static const String submitForm = 'إرسال النموذج';
  static const String formSaved = 'تم حفظ المسودة';
  static const String formSubmitted = 'تم إرسال النموذج بنجاح';
  static const String formSubmittedOffline = 'تم حفظ النموذج وسيُرسل عند الاتصال';
  static const String gpsRequired = 'موقع GPS مطلوب';
  static const String captureLocation = 'التقاط الموقع';
  static const String addPhoto = 'إضافة صورة';
  static const String requiredField = 'هذا الحقل مطلوب';
  static const String required = 'مطلوب';
  static const String submit = 'إرسال';
  static const String submitSuccess = 'تم الإرسال بنجاح';
  static const String draftSaved = 'تم حفظ المسودة';
  static const String draft = 'مسودة';
  static const String submitted = 'مُرسَل';
  static const String reviewed = 'قيد المراجعة';
  static const String approved = 'معتمد';
  static const String rejected = 'مرفوض';

  // ─── Submissions ──────────────────────────────────────────────────────────
  static const String mySubmissions = 'إرسالياتي';
  static const String allSubmissions = 'جميع الإرساليات';
  static const String submissionDetails = 'تفاصيل الإرسالية';
  static const String approveSubmission = 'اعتماد';
  static const String rejectSubmission = 'رفض';
  static const String reviewNotes = 'ملاحظات المراجعة';

  // ─── Shortages ────────────────────────────────────────────────────────────
  static const String supplyShortages = 'نواقص التجهيزات';
  static const String reportShortage = 'الإبلاغ عن نقص';
  static const String severity = 'الخطورة';
  static const String critical = 'حرج';
  static const String high = 'عالي';
  static const String medium = 'متوسط';
  static const String low = 'منخفض';
  static const String resolved = 'محلول';
  static const String pending = 'قيد الانتظار';

  // ─── Map ──────────────────────────────────────────────────────────────────
  static const String fieldMap = 'الخريطة الميدانية';
  static const String submissions_map = 'إرساليات';
  static const String shortages_map = 'نواقص';
  static const String heatmap = 'خريطة الكثافة';
  static const String clustering = 'تجميع النقاط';

  // ─── Analytics ────────────────────────────────────────────────────────────
  static const String performanceAnalytics = 'تحليلات الأداء';
  static const String submissionTrend = 'اتجاه الإرساليات';
  static const String governorateRanking = 'ترتيب المحافظات';
  static const String exportCSV = 'تصدير CSV';
  static const String exportPDF = 'تصدير PDF';
  static const String filterByDate = 'تصفية حسب التاريخ';
  static const String filterByGovernorate = 'تصفية حسب المحافظة';
  static const String last7Days = 'آخر 7 أيام';
  static const String last30Days = 'آخر 30 يوم';
  static const String last90Days = 'آخر 90 يوم';
  static const String thisMonth = 'هذا الشهر';

  // ─── AI ───────────────────────────────────────────────────────────────────
  static const String aiWelcome = 'مرحباً! أنا مساعدك الذكي لتحليل بيانات حملة التطعيم. كيف يمكنني مساعدتك؟';
  static const String aiTyping = 'جاري الكتابة...';
  static const String aiThinking = 'جاري التفكير...';
  static const String aiInputHint = 'اسألني عن البيانات والإحصائيات...';
  static const String askQuestion = 'اسألني أي شيء...';
  static const String aiSend = 'إرسال';
  static const String aiClearHistory = 'مسح المحادثة';
  static const String aiInsights = 'رؤى AI';

  // ─── References ──────────────────────────────────────────────
  static const String references = 'المراجع والكتب';
  static const String addReference = 'إضافة مرجع';
  static const String editReference = 'تعديل المرجع';
  static const String deleteReference = 'حذف المرجع';
  static const String referenceCategory = 'التصنيف';
  static const String noReferences = 'لا توجد مراجع متاحة';

  // ─── Users / Admin ────────────────────────────────────────────────────────
  static const String addUser = 'إضافة مستخدم';
  static const String editUser = 'تعديل المستخدم';
  static const String deleteUser = 'حذف المستخدم';
  static const String userRole = 'الدور';
  static const String userGovernorate = 'المحافظة';
  static const String userDistrict = 'المنطقة';
  static const String activateUser = 'تفعيل';
  static const String deactivateUser = 'إلغاء التفعيل';
  static const String roleAdmin = 'مدير النظام';
  static const String roleCentral = 'مركزي';
  static const String roleGovernorate = 'محافظة';
  static const String roleDistrict = 'منطقة';
  static const String roleTeamLead = 'مشرف فريق';

  // ─── Offline / Sync ───────────────────────────────────────────────────────
  static const String offline = 'غير متصل';
  static const String online = 'متصل';
  static const String syncing = 'جاري المزامنة...';
  static const String syncComplete = 'تمت المزامنة';
  static const String syncFailed = 'فشلت المزامنة';
  static const String pendingItems = 'عناصر معلقة';
  static const String offlineSaved = 'تم الحفظ بدون إنترنت';

  // ─── Common ───────────────────────────────────────────────────────────────
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String confirm = 'تأكيد';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String view = 'عرض';
  static const String search = 'بحث';
  static const String filter = 'تصفية';
  static const String refresh = 'تحديث';
  static const String retry = 'إعادة المحاولة';
  static const String loading = 'جاري التحميل...';
  static const String error = 'خطأ';
  static const String success = 'نجاح';
  static const String warning = 'تحذير';
  static const String noData = 'لا توجد بيانات';
  static const String noResults = 'لا توجد نتائج';
  static const String noInternet = 'لا يوجد اتصال بالإنترنت';
  static const String tryAgain = 'حاول مرة أخرى';
  static const String yes = 'نعم';
  static const String no = 'لا';
  static const String ok = 'حسناً';
  static const String close = 'إغلاق';
  static const String back = 'رجوع';
  static const String next = 'التالي';
  static const String done = 'تم';
  static const String all = 'الكل';
  static const String none = 'لا شيء';
  static const String governorate = 'المحافظة';
  static const String district = 'المنطقة / المديرية';
  static const String selectGovernorate = 'اختر محافظة';
  static const String selectDistrict = 'اختر منطقة';
  static const String date = 'التاريخ';
  static const String time = 'الوقت';
  static const String notes = 'ملاحظات';
  static const String name = 'الاسم';
  static const String phone = 'رقم الهاتف';
  static const String address = 'العنوان';
  static const String location = 'الموقع';

  // ─── Errors ───────────────────────────────────────────────────────────────
  static const String errorGeneral = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
  static const String errorNetwork = 'تأكد من اتصالك بالإنترنت.';
  static const String errorPermission = 'ليس لديك صلاحية القيام بهذا الإجراء.';
  static const String errorNotFound = 'السجل المطلوب غير موجود.';
  static const String errorValidation = 'يرجى التحقق من البيانات المدخلة.';
  static const String errorGPS = 'تعذر الحصول على موقع GPS. تأكد من تفعيل الموقع.';
  static const String errorCamera = 'تعذر الوصول للكاميرا. يرجى منح الإذن.';
}
