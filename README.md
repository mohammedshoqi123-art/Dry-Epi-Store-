# منصة مشرف EPI — EPI Supervisor Platform

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-green?style=for-the-badge&logo=supabase&logoColor=white)
![MiMo AI](https://img.shields.io/badge/MiMo-AI-orange?style=for-the-badge&logo=xiaomi&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen?style=for-the-badge)

**نظام إشراف ميداني متكامل لحملات التطعيم**  
*Field Supervision System for Immunization Campaigns*

</div>

---

## 📋 نظرة عامة

منصة **مشرف EPI** هي نظام SaaS متكامل لإدارة والإشراف على حملات التطعيم الميدانية في اليمن.

تتيح المنصة للمشرفين على مختلف المستويات الإدارية إدارة النماذج الميدانية، تتبع النواقص، ومراقبة الأداء — حتى بدون إنترنت.

---

## ✨ المميزات الرئيسية

| الميزة | الوصف |
|--------|--------|
| 🔐 RBAC | 5 مستويات صلاحيات (admin > central > governorate > district > data_entry) |
| 📝 نماذج ديناميكية | محرك JSON Schema قابل للتخصيص بالكامل |
| 📡 Offline First | عمل كامل بدون إنترنت مع مزامنة تلقائية |
| 🗺️ خرائط تفاعلية | OpenStreetMap + clustering + heatmap |
| 📊 تحليلات | لوحة KPI مع رسوم بيانية وتصدير CSV/PDF |
| 🤖 ذكاء اصطناعي | مساعد MiMo للتحليل والرؤى باللغة العربية |
| 🔔 مراقبة | Sentry + Supabase logs |
| 📱 متعدد المنصات | Android APK + Web |

---

## 🏗️ البنية المعمارية

```
EPI-Supervisor/
├── apps/
│   └── mobile/                    # Flutter App (Android + Web PWA)
│       ├── lib/
│       │   ├── main.dart          # نقطة الدخول الرئيسية
│       │   ├── router/            # التوجيه (go_router)
│       │   └── providers/         # حالة التطبيق (Riverpod)
│       └── test/                  # الاختبارات
├── packages/
│   ├── core/                      # منطق العمل، API، Auth، Offline، Sync
│   │   └── lib/src/
│   │       ├── auth/              # المصادقة وإدارة الجلسات
│   │       ├── api/               # عميل API الموحد
│   │       ├── offline/           # نظام Offline-First
│   │       ├── security/          # التشفير و RBAC
│   │       ├── ai/                # خدمات الذكاء الاصطناعي
│   │       └── database/          # خدمات قاعدة البيانات
│   ├── shared/                    # مكونات UI، Theme، Models
│   └── features/                  # وحدات الميزات (لوحة الإدارة، إنشاء النماذج)
├── supabase/
│   ├── functions/                 # 7 Edge Functions (Deno/TypeScript)
│   │   ├── _shared/               # 🔗 وظائف مشتركة (Auth, CORS)
│   │   ├── submit-form/           # إرسال النماذج
│   │   ├── sync-offline/          # مزامنة البيانات غير المتصلة
│   │   ├── ai-chat/               # محادثة AI
│   │   ├── get-analytics/         # الإحصائيات
│   │   ├── get-dashboard-stats/   # إحصائيات لوحة التحكم
│   │   ├── get-governorate-report/# تقارير المحافظات
│   │   ├── admin-actions/         # إدارة المستخدمين
│   │   └── create-admin/          # إنشاء مدير
│   └── migrations/                # هيكل قاعدة البيانات
│       ├── 001_schema.sql         # الجداول + RLS + المشغلات
│       └── 002_seed_data.sql      # 19 محافظة + بيانات تجريبية
├── scripts/                       # سكريبتات البناء والنشر
├── melos.yaml                     # إدارة Monorepo
└── .github/workflows/ci.yml       # CI/CD Pipeline
```

---

## 🚀 دليل التشغيل

### المتطلبات الأساسية

| الأداة | الإصدار المطلوب | الرابط |
|--------|-----------------|--------|
| Flutter SDK | 3.19+ | [flutter.dev](https://flutter.dev) |
| Dart SDK | 3.3+ | مُرفق مع Flutter |
| Supabase CLI | أحدث | `npm install -g supabase` |
| حساب Supabase | — | [supabase.com](https://supabase.com) |
| مفتاح MiMo AI (اختياري) | — | [api.xiaomimimo.com](https://api.xiaomimimo.com) |

### الخطوة 1: إعداد المشروع

```bash
# استنساخ المشروع
git clone https://github.com/mohammedshoqi123-art/EPI-Supervisor.git
cd EPI-Supervisor

# نسخ ملف البيئة
cp .env.example .env

# تعديل القيم في .env
nano .env  # أو أي محرر نصوص
```

### الخطوة 2: إعداد Supabase

```bash
# تسجيل الدخول إلى Supabase CLI
supabase login

# ربط المشروع
supabase link --project-ref YOUR_PROJECT_REF

# تطبيق migrations
supabase db push

# نشر Edge Functions
supabase functions deploy
```

### الخطوة 3: متغيرات البيئة في Supabase Edge Functions

اضف المتغيرات التالية في Supabase Dashboard → Edge Functions → Secrets:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
MIMO_API_KEY=your-mimo-api-key
ALLOWED_ORIGINS=https://your-domain.com,http://localhost:3000
CREATE_ADMIN_SECRET=your-random-secret
```

> ⚠️ **لا تضع `*` في `ALLOWED_ORIGINS` في الإنتاج!** حدد النطاقات المسموحة فقط.

### الخطوة 4: تشغيل التطبيق

```bash
cd apps/mobile

# تثبيت الحزم
flutter pub get

# تشغيل على Android
flutter run --dart-define=SUPABASE_URL="https://..." --dart-define=SUPABASE_ANON_KEY="..."

# تشغيل على الويب
flutter run -d chrome --dart-define=SUPABASE_URL="..." --dart-define=SUPABASE_ANON_KEY="..."
```

### الخطوة 5: بناء APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://..." \
  --dart-define=SUPABASE_ANON_KEY="..." \
  --dart-define=ENCRYPTION_KEY="your-32-char-minimum-key"
```

---

## 🔐 نظام الصلاحيات (RBAC)

| الدور | المستوى | الصلاحيات |
|-------|---------|-----------|
| **admin** | 5 | وصول كامل — إدارة المستخدمين، النماذج، المحافظات |
| **central** | 4 | رؤية كل البيانات، إدارة النماذج، الموافقة/الرفض |
| **governorate** | 3 | رؤية بيانات محافظته، الموافقة/الرفض، التصدير، AI |
| **district** | 2 | رؤية بيانات مديريته، التصدير |
| **data_entry** | 1 | إرسال النماذج، رؤية بياناته فقط |

---

## 🗄️ قاعدة البيانات

| الجدول | الغرض |
|--------|--------|
| `profiles` | بيانات المستخدمين + الأدوار |
| `governorates` | 19 محافظة يمنية + بيانات GIS |
| `districts` | المديريات التابعة للمحافظات |
| `forms` | تعريفات النماذج (JSON Schema) |
| `form_submissions` | الإرساليات + GPS + الصور |
| `supply_shortages` | نواقص التجهيزات |
| `audit_logs` | سجل تدقيق غير قابل للتعديل |
| `health_facilities` | المنشآت الصحية |
| `notifications` | إشعارات المستخدمين |
| `app_settings` | إعدادات التطبيق |

---

## 📡 نظام Offline-First

المنصة تعمل بشكل كامل بدون إنترنت:

1. **الحفظ المحلي أولاً** — كل البيانات تُحفظ في Hive أولاً
2. **طابور المزامنة** — أولويات: Critical → High → Normal → Low
3. **إعادة المحاولة التلقائية** — 10s → 30s → 90s → 5min → 15min
4. **حل التعارضات** — 4 استراتيجيات (Smart Merge)
5. **مزامنة تلقائية** — كل 5 دقائق + عند استعادة الاتصال

---

## 🔒 الأمان

- ✅ AES-256-GCM مع PBKDF2 (100,000 iterations) للتشفير المحلي
- ✅ Row Level Security على جميع الجداول
- ✅ JWT validation في كل Edge Function (بدون fallback غير آمن)
- ✅ Rate limiting (10 طلبات/دقيقة) مع fail-closed
- ✅ CORS مقيد بنطاق محدد
- ✅ Audit logs لجميع العمليات
- ✅ Soft delete لجميع السجلات

---

## 🔄 CI/CD Pipeline

```
push to main → Analyze & Test → Build APK → Build Web → Deploy Pages → Deploy Functions
```

---

## 📦 التقنيات المستخدمة

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
- MiMo API (Xiaomi) — OpenAI-compatible endpoint

---

<div align="center">

Built with ❤️ | منصة مشرف EPI v1.0.0

</div>
