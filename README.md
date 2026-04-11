# منصة مشرف EPI — EPI Supervisor Platform

<div align="center">

![EPI Supervisor](https://img.shields.io/badge/Platform-Flutter%203.19+-blue?style=for-the-badge&logo=flutter)
![Backend](https://img.shields.io/badge/Backend-Supabase-green?style=for-the-badge&logo=supabase)
![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.0.0-orange?style=for-the-badge)

**نظام إشراف ميداني متكامل لحملات التطعيم**  
*Field Supervision System for Immunization Campaigns*

</div>

---

## 📋 نظرة عامة

منصة **مشرف EPI** هي نظام SaaS متكامل لإدارة والإشراف على حملات التطعيم الميداني في العراق.  
تتيح المنصة للمشرفين على مختلف المستويات الإدارية (مركزي، محافظة، منطقة، مدخل بيانات) إدارة النماذج الميدانية، تتبع النواقص، ومراقبة الأداء.

## ✨ المميزات الرئيسية

| الميزة | الوصف |
|--------|--------|
| 🔐 RBAC | 5 مستويات صلاحيات (admin > central > governorate > district > data_entry) |
| 📝 نماذج ديناميكية | محرك JSON Schema قابل للتخصيص بالكامل |
| 📡 Offline First | عمل كامل بدون إنترنت مع مزامنة تلقائية |
| 🗺️ خرائط تفاعلية | OpenStreetMap + clustering + heatmap |
| 📊 تحليلات | لوحة KPI مع رسوم بيانية وتصدير CSV/PDF |
| 🤖 ذكاء اصطناعي | مساعد Gemini للتحليل والرؤى باللغة العربية |
| 🔔 مراقبة | Sentry + Supabase logs |
| 📱 متعدد المنصات | Android APK + Web (موحّد) |

## 🏗️ البنية المعمارية

```
supervisor app/
├── apps/
│   ├── mobile/          # Flutter app (Android + Web PWA)
│   └── web/             # Flutter Web (مخصص للويب)
├── packages/
│   ├── core/            # Business logic, API, Auth, Offline, Sync, AI
│   ├── shared/          # UI components, Theme, Extensions, Strings
│   └── features/        # Feature modules (Forms, Maps, Analytics, Chat)
├── supabase/
│   ├── functions/       # 5 Edge Functions (Deno/TypeScript)
│   │   ├── create-admin/
│   │   ├── submit-form/
│   │   ├── get-analytics/
│   │   ├── ai-chat/
│   │   └── sync-offline/
│   └── migrations/
│       ├── 001_initial_schema.sql  # Schema + RLS + Triggers
│       └── 002_seed_data.sql       # 19 محافظة + بيانات تجريبية
├── scripts/
│   ├── build_and_deploy.ps1  # بناء APK + Web
│   └── setup_supabase.ps1    # إعداد Supabase
└── .env.example              # متغيرات البيئة
```

## 🚀 خطوات التشغيل

### المتطلبات

- Flutter SDK 3.19+
- Dart SDK 3.3+
- حساب Supabase
- مفتاح Gemini API

### 1. إعداد المشروع

```powershell
# نسخ ملف البيئة
Copy-Item .env.example .env

# تعديل القيم في .env
notepad .env
```

### 2. إعداد Supabase

```powershell
# تثبيت Supabase CLI
npm install -g supabase

# تسجيل الدخول
supabase login

# إعداد كامل (migrations + seed + functions + admin)
.\scripts\setup_supabase.ps1 `
  -projectRef "YOUR_PROJECT_REF" `
  -supabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -serviceRoleKey "YOUR_SERVICE_ROLE_KEY" `
  -geminiApiKey "YOUR_GEMINI_KEY"
```

### 3. تشغيل التطبيق محلياً

```powershell
cd apps\mobile

# تثبيت الحزم
flutter pub get

# تشغيل في وضع debug
flutter run --dart-define=SUPABASE_URL="https://..." --dart-define=SUPABASE_ANON_KEY="..."

# تشغيل على الويب
flutter run -d chrome --dart-define=SUPABASE_URL="..." --dart-define=SUPABASE_ANON_KEY="..."
```

### 4. بناء APK (Release)

```powershell
.\scripts\build_and_deploy.ps1 -apk `
  -supabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -supabaseAnonKey "YOUR_ANON_KEY" `
  -geminiApiKey "YOUR_GEMINI_KEY"

# APK يُحفظ في: build\outputs\epi-supervisor-v1.0.0.apk
```

### 5. بناء ونشر الويب

```powershell
.\scripts\build_and_deploy.ps1 -web `
  -supabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -supabaseAnonKey "YOUR_ANON_KEY"

# نشر على Vercel
vercel deploy build\outputs\web --prod

# أو خدمة محلية
cd build\outputs\web
python -m http.server 8080
```

## 🔐 بيانات الدخول الافتراضية

> ⚠️ **كلمة المرور الافتراضية موجودة في `.env.example` — غيّرها فوراً بعد أول تسجيل دخول!**

يتم إنشاء حساب Admin أثناء تشغيل `setup_supabase.ps1` أو `scripts/setup.sh`.
راجع ملف `.env` للحصول على الإيميل وكلمة المرور.

## 🗄️ قاعدة البيانات

| الجدول | الغرض |
|--------|--------|
| `profiles` | بيانات المستخدمين + الأدوار |
| `governorates` | المحافظات (19 محافظة عراقية) + GIS |
| `districts` | المناطق/المديريات |
| `forms` | تعريفات النماذج (JSON Schema) |
| `form_submissions` | بيانات الإرساليات + GPS + الصور |
| `supply_shortages` | نواقص التجهيزات |
| `audit_logs` | سجل تدقيق غير قابل للتعديل |

## 🔒 الأمان

- ✅ Row Level Security على جميع الجداول
- ✅ تشفير التخزين المحلي (AES XOR)
- ✅ JWT validation في كل Edge Function
- ✅ Rate limiting للـ API
- ✅ Audit logs لجميع العمليات
- ✅ Soft delete لجميع السجلات

## 📦 Edge Functions

| الوظيفة | الغرض |
|---------|--------|
| `create-admin` | إنشاء مستخدم admin |
| `submit-form` | إرسال النماذج مع التحقق |
| `get-analytics` | تجميع إحصائيات KPI |
| `ai-chat` | محادثة Gemini + رؤى |
| `sync-offline` | مزامنة الإرساليات الغير متصل |

## 🤖 التقنيات المستخدمة

**Frontend:**
- Flutter 3.19+ (Dart)
- flutter_riverpod (State Management)
- go_router (Navigation)
- flutter_map + latlong2 (Maps)
- fl_chart (Charts)
- hive_flutter (Offline Storage)
- supabase_flutter (Backend)
- sentry_flutter (Monitoring)

**Backend:**
- Supabase (PostgreSQL + Auth + Realtime + Storage)
- Edge Functions (Deno/TypeScript)
- PostGIS (Geo support)
- Row Level Security

**AI:**
- Google Gemini 1.5 Flash (Arabic)

---

<div align="center">
Built with ❤️ | منصة مشرف EPI v1.0.0
</div>
