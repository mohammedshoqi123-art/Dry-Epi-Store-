<div align="center">

# 🏥 منصة مشرف EPI

### نظام إشراف ميداني متكامل لحملات التطعيم
*Field Supervision System for Immunization Campaigns*

![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)
![TypeScript](https://img.shields.io/badge/Edge%20Functions-Deno/TS-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-PostGIS-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-2.1.0-brightgreen?style=for-the-badge)

[📱 تحميل APK](https://github.com/mohammedshoqi123-art/EPI-Supervisor/releases) · [🌐 لوحة الإدارة](https://mohammedshoqi123-art.github.io/EPI-Supervisor/) · [📖 الدليل](docs/user-guide/) · [🐛 الإبلاغ عن مشكلة](https://github.com/mohammedshoqi123-art/EPI-Supervisor/issues)

</div>

---

## 📋 نظرة عامة

**منصة مشرف EPI** هي نظام SaaS متكامل لإدارة والإشراف على حملات التطعيم الميدانية في اليمن. تهدف إلى تحسين كفاءة الإشراف الميداني وتوفير بيانات دقيقة للقرارات الصحية.

### لماذا مشرف EPI؟

<table>
<tr>
<td width="50%">

**التحديات الحالية:**
- 📝 تعبئة استمارات ورقية بطيئة
- 📡 فقدان بيانات في المناطق المنعزلة
- 📊 تقارير متأخرة وغير دقيقة
- 🔍 صعوبة تتبع النواقص الميدانية

</td>
<td width="50%">

**الحلول:**
- ✅ نماذج إلكترونية ذكية
- ✅ عمل بدون إنترنت + مزامنة تلقائية
- ✅ لوحات تحليلات فورية
- ✅ خرائط تفاعلية + GPS

</td>
</tr>
</table>

---

## ✨ المميزات الرئيسية

### 🔐 نظام الصلاحيات الهرمي (RBAC)
| الدور | المستوى | الوصف |
|-------|---------|-------|
| 🔴 مدير النظام | 5 | وصول كامل — إدارة كل شيء |
| 🟣 مركزي | 4 | رؤية كل البيانات + إدارة النماذج |
| 🔵 محافظة | 3 | رؤية بيانات محافظته + الموافقة/الرفض |
| 🟢 مديرية | 2 | رؤية بيانات مديريته + التصدير |
| ⚪ إدخال بيانات | 1 | إرسال النماذج + رؤية بياناته فقط |

### 📝 نماذج ديناميكية
- محرك JSON Schema قابل للتخصيص بالكامل
- دعم الحقول: نص، رقم، اختيار، تاريخ، صورة، GPS
- إلزامية GPS/صورة حسب النموذج
- تحديث النماذج عبر السيرفر بدون تحديث التطبيق

### 📡 Offline First — أهم ميزة
```
الحفظ المحلي أولاً → طابور المزامنة → إعادة المحاولة التلقائية → حل التعارضات
```
- **Always-Save-First**: البيانات تُحفظ في Hive أولاً دائماً
- **Priority Queue**: إرسالات التطعيم (critical) تُرسل أولاً
- **Exponential Backoff**: 10s → 30s → 90s → 5min → 15min
- **Dead-Letter Queue**: العناصر الفاشلة تنتقل لمراجعة يدوية
- **Smart Merge**: حل التعارضات بـ 4 استراتيجيات ذكية
- **Auto-Sync**: كل 5 دقائق + عند استعادة الاتصال

### 🗺️ خرائط تفاعلية
- OpenStreetMap مع clustering للنقاط
- Heatmap للإرساليات
- عرض المواقع GPS للإرساليات
- تحديد المناطق على الخريطة

### 📊 تحليلات ولوحة تحكم
- مؤشرات KPI حية (إرساليات، نواقص، إنجاز)
- رسوم بيانية: دائري، خطي، أعمدة
- تقارير PDF قابلة للاستخراج
- فلترة حسب المحافظة/المديرية/الفترة

### 🤖 مساعد ذكي (MiMo AI)
- تحليل البيانات باللغة العربية
- رؤى وتوصيات ذكية
- إجابة على أسئلة حول بيانات الحملة
- تنبؤات النواقص

---

## 🏗️ البنية المعمارية

```
EPI-Supervisor/
├── apps/
│   ├── mobile/                          📱 تطبيق Flutter (Android + Web PWA)
│   │   ├── lib/
│   │   │   ├── main.dart                نقطة الدخول
│   │   │   ├── router/                  التوجيه (go_router)
│   │   │   ├── providers/               الحالة (Riverpod)
│   │   │   └── screens/                 الشاشات (~20 شاشة)
│   │   └── test/                        الاختبارات
│   └── admin-web/                       🌐 لوحة إدارة الويب (React + Vite)
│       └── src/
│           ├── pages/                   صفحات الإدارة (~15 صفحة)
│           └── components/              مكونات UI
├── packages/
│   ├── core/                            🧠 منطق العمل الأساسي
│   │   └── lib/src/
│   │       ├── auth/                    المصادقة وإدارة الجلسات
│   │       ├── api/                     عميل API الموحد
│   │       ├── offline/                 نظام Offline-First
│   │       ├── security/                التشفير و RBAC
│   │       ├── ai/                      خدمات الذكاء الاصطناعي
│   │       └── database/                خدمات قاعدة البيانات
│   ├── shared/                          🎨 مكونات UI، Theme، Models
│   └── features/                        ⚡ وحدات الميزات المتقدمة
├── supabase/
│   ├── functions/                       ⚡ 14 Edge Function (Deno/TS)
│   │   ├── _shared/                     وظائف مشتركة (Auth, CORS)
│   │   ├── submit-form/                 إرسال النماذج
│   │   ├── sync-offline/               مزامنة البيانات
│   │   ├── ai-chat/                     محادثة AI
│   │   ├── get-analytics/              الإحصائيات
│   │   ├── get-advanced-reports/        التقارير المتقدمة + PDF
│   │   ├── admin-actions/              إدارة المستخدمين
│   │   └── ... (10 أكثر)
│   └── migrations/                      هيكل قاعدة البيانات
│       ├── 001_schema.sql               الجداول + RLS + المشغلات
│       └── 002_seed_data.sql            22 محافظة + أحياء + مرافق صحية
├── scripts/                             🔧 سكريبتات البناء والنشر
├── docs/                                📚 التوثيق
├── melos.yaml                           📦 إدارة Monorepo
└── .github/workflows/ci.yml             🔄 CI/CD Pipeline
```

---

## 📸 لقطات الشاشة

### لوحة التحكم الرئيسية
<div align="center">
<table>
<tr>
<td align="center" width="200">
<b>لوحة التحكم</b><br/>
<sub>مؤشرات KPI + رسوم بيانية<br/>إجراءات سريعة + تقرير PDF</sub>
</td>
<td align="center" width="200">
<b>تعبئة النماذج</b><br/>
<sub>نماذج ديناميكية + GPS<br/>رفع صور + حفظ محلي</sub>
</td>
<td align="center" width="200">
<b>الخرائط</b><br/>
<sub>OpenStreetMap + clustering<br/>عرض الإرساليات على الخريطة</sub>
</td>
</tr>
<tr>
<td align="center" width="200">
<b>المحادثة الداخلية</b><br/>
<sub>تواصل بين المستخدمين<br/>إشعارات فورية</sub>
</td>
<td align="center" width="200">
<b>المساعد الذكي</b><br/>
<sub>MiMo AI بالعربية<br/>تحليل + رؤى + توصيات</sub>
</td>
<td align="center" width="200">
<b>إدارة المستخدمين</b><br/>
<sub>بحث + تصفية<br/>تفعيل/تعطيل</sub>
</td>
</tr>
</table>
</div>

---

## 🚀 البدء السريع

### المتطلبات

| الأداة | الإصدار | ملاحظة |
|--------|---------|--------|
| Flutter SDK | 3.19+ | [flutter.dev](https://flutter.dev) |
| Dart SDK | 3.3+ | مرفق مع Flutter |
| Supabase CLI | أحدث | `npm install -g supabase` |
| حساب Supabase | — | مجاني حتى 50,000 مستخدم |

### 1️⃣ استنساخ المشروع

```bash
git clone https://github.com/mohammedshoqi123-art/EPI-Supervisor.git
cd EPI-Supervisor
```

### 2️⃣ إعداد Supabase

```bash
# تسجيل الدخول
supabase login

# ربط المشروع
supabase link --project-ref YOUR_PROJECT_REF

# تطبيق هيكل قاعدة البيانات + البيانات الأولية
supabase db push

# نشر Edge Functions
supabase functions deploy
```

### 3️⃣ إعداد متغيرات البيئة

```bash
cp .env.example .env
nano .env  # عدّل القيم
```

**متغيرات Supabase Edge Functions** (في Supabase Dashboard → Edge Functions → Secrets):
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
MIMO_API_KEY=your-mimo-api-key
ALLOWED_ORIGINS=https://your-domain.com,http://localhost:5173
ENCRYPTION_KEY=your-32-char-minimum-secure-key
```

> ⚠️ **لا تضع `*` في `ALLOWED_ORIGINS` في الإنتاج!** حدد النطاقات المسموحة فقط.

### 4️⃣ تشغيل التطبيق

```bash
cd apps/mobile
flutter pub get

# تشغيل على Android
flutter run --dart-define=SUPABASE_URL="https://..." \
  --dart-define=SUPABASE_ANON_KEY="..." \
  --dart-define=ENCRYPTION_KEY="your-key"

# تشغيل على الويب
flutter run -d chrome --dart-define=SUPABASE_URL="..." \
  --dart-define=SUPABASE_ANON_KEY="..." \
  --dart-define=ENCRYPTION_KEY="your-key"
```

### 5️⃣ بناء APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://..." \
  --dart-define=SUPABASE_ANON_KEY="..." \
  --dart-define=ENCRYPTION_KEY="your-key"
```

---

## 🗄️ قاعدة البيانات

| الجدول | الوصف | السجلات الافتراضية |
|--------|-------|-------------------|
| `profiles` | المستخدمون + الأدوار | — (إنشاء تلقائي) |
| `governorates` | المحافظات اليمنية | 22 محافظة |
| `districts` | المديريات | ~120 مديرية |
| `health_facilities` | المرافق الصحية | ~50 مرفق |
| `forms` | تعريفات النماذج | — (من لوحة الإدارة) |
| `form_submissions` | الإرساليات + GPS + صور | — |
| `supply_shortages` | نواقص التجهيزات | — |
| `audit_logs` | سجل تدقيق | تلقائي |
| `notifications` | الإشعارات | تلقائي |
| `app_settings` | إعدادات النظام | 11 إعداد افتراضي |

---

## 🔒 الأمان

| الطبقة | التقنية | التفاصيل |
|--------|---------|----------|
| 🔐 التشفير المحلي | AES-256-GCM | PBKDF2 (100K iterations) |
| 🛡️ قاعدة البيانات | Row Level Security | كل الجداول محمية |
| 🔑 المصادقة | JWT (Supabase Auth) | بدون fallback غير آمن |
| ⏱️ Rate Limiting | Edge Functions | 10 طلبات/دقيقة (fail-closed) |
| 🌐 CORS | Allowlist | مُقيد بنطاق محدد |
| 📋 Audit Logs | تلقائي | جميع العمليات مسجلة |
| 🗑️ Soft Delete | كل الجداول | حذف آمن قابل للاستعادة |

---

## 🔄 CI/CD Pipeline

```
push to main
    ↓
┌─────────────┐
│ Analyze     │ → flutter analyze + dart format
│ & Test      │ → flutter test --coverage
└──────┬──────┘
       ↓
┌─────────────┐
│ Build APK   │ → flutter build apk --release
└──────┬──────┘
       ↓
┌─────────────┐
│ Build Web   │ → flutter build web --release
└──────┬──────┘
       ↓
┌─────────────┐
│ Deploy      │ → GitHub Pages + Supabase Functions
│ & Release   │ → Automatic release with APK
└─────────────┘
```

---

## 📦 التقنيات المستخدمة

**الواجهة الأمامية:**
| التقنية | الاستخدام |
|---------|-----------|
| Flutter 3.19+ | إطار العمل الرئيسي |
| flutter_riverpod | إدارة الحالة |
| go_router | التوجيه |
| flutter_map + latlong2 | الخرائط |
| fl_chart | الرسوم البيانية |
| hive_flutter | التخزين المحلي |
| supabase_flutter | الاتصال بالخادم |
| sentry_flutter | مراقبة الأخطاء |

**الخلفية:**
| التقنية | الاستخدام |
|---------|-----------|
| Supabase | PostgreSQL + Auth + Realtime |
| Edge Functions | Deno/TypeScript |
| PostGIS | دعم جغرافي |
| Row Level Security | أمان قاعدة البيانات |

**لوحة الويب:**
| التقنية | الاستخدام |
|---------|-----------|
| React 18 | إطار العمل |
| Vite | البناء السريع |
| Tailwind CSS | التصميم |
| Recharts | الرسوم البيانية |

---

## 📚 التوثيق

| الملف | الوصف |
|-------|-------|
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | دليل الإعداد التفصيلي |
| [docs/sync_system_v2.md](docs/sync_system_v2.md) | توثيق نظام المزامنة |
| [docs/epi-knowledge-base.md](docs/epi-knowledge-base.md) | قاعدة معرفة التطعيم |
| [docs/user-guide/](docs/user-guide/) | دليل المستخدم (PDF + DOCX) |
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | تقرير الفحص الشامل |

---

## 🤝 المساهمة

هذا مشروع مملوك (Proprietary). المساهمات من فريق التطوير الداخلي فقط.

1. إنشاء فرع من `develop`
2. تنفيذ التغييرات + اختبارات
3. Pull Request إلى `develop`
4. مراجعة + دمج إلى `main`

---

## 📄 الترخيص

**Proprietary** — جميع الحقوق محفوظة. يُمنع النسخ أو التوزيع بدون إذن كتابي.

---

<div align="center">

**Built with ❤️ for Yemen's Healthcare**

منصة مشرف EPI v2.1.0

</div>
