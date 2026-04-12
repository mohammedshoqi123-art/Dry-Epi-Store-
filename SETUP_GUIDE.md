# دليل تشغيل منصة مشرف EPI — Setup Guide

## 📋 المتطلبات المسبقة

- **Flutter SDK** 3.19+ (3.22 مُنصح)
- **Node.js** 18+ (لـ Supabase CLI)
- **حساب Supabase** مع مشروع مُنشأ
- **Supabase CLI**: `npm install -g supabase`

---

## 🚀 خطوات التشغيل

### الخطوة 1: إعداد Supabase

1. اذهب إلى [supabase.com/dashboard](https://supabase.com/dashboard)
2. أنشئ مشروع جديد أو استخدم المشروع الموجود
3. انسخ من **Project Settings → API**:
   - `Project URL` (مثل: `https://xxxxx.supabase.co`)
   - `anon public` key
   - `service_role` key

### الخطوة 2: إعداد المتغيرات

```bash
# نسخ ملف البيئة
cp .env.example .env

# عدّل القيم
nano .env
```

**المتغيرات المطلوبة:**
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_PROJECT_REF=your-project-ref
```

### الخطوة 3: إعداد قاعدة البيانات

```bash
# تسجيل الدخول لـ Supabase
supabase login

# ربط المشروع
supabase link --project-ref YOUR_PROJECT_REF

# تشغيل migrations
supabase db push

# نشر Edge Functions
supabase functions deploy --project-ref YOUR_PROJECT_REF
```

**أو استخدم السكربت:**
```bash
chmod +x scripts/setup_supabase.sh
./scripts/setup_supabase.sh
```

### الخطوة 4: التأكد من Admin

المستخدم `admin@example.com` يجب أن يكون موجوداً في:
1. **Authentication** → Users (مُفعّل)
2. **جدول profiles** → بدور `admin`

إذا لم يكن موجوداً، استدعي Edge Function:
```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/create-admin" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "YOUR_PASSWORD",
    "full_name": "مدير النظام",
    "role": "admin"
  }'
```

### الخطوة 5: تشغيل التطبيق

```bash
cd apps/mobile
flutter pub get

# تشغيل على الويب
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://..." \
  --dart-define=SUPABASE_ANON_KEY="..."

# بناء APK
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://..." \
  --dart-define=SUPABASE_ANON_KEY="..."
```

---

## 🔧 استكشاف الأخطاء

### Supabase فارغ (لا جداول)
```bash
# تأكد من تشغيل migrations
supabase db push

# أو أنشئ الجداول يدوياً
psql "postgresql://..." -f supabase/migrations/001_initial_schema.sql
psql "postgresql://..." -f supabase/migrations/002_seed_data.sql
```

### فشل بناء APK
```bash
# تأكد من إنشاء local.properties
echo "flutter.sdk=$(dirname $(dirname $(which flutter)))" > apps/mobile/android/local.properties

# نظّف وابنِ من جديد
cd apps/mobile
flutter clean
flutter pub get
flutter build apk --release ...
```

### Admin لا يستطيع الدخول
1. تحقق من أن المستخدم موجود في Authentication → Users
2. تحقق من أن البريد مُفعّل (email_confirm = true)
3. تحقق من أن جدول profiles يحتوي على السجل بدور admin

---

## 📁 هيء المشروع

```
EPI-Supervisor/
├── apps/mobile/          # تطبيق Flutter الرئيسي
├── packages/
│   ├── core/            # منطق الأعمال (Auth, API, Offline, Sync)
│   ├── shared/          # مكونات واجهة المستخدم
│   └── features/        # وحدات الميزات
├── supabase/
│   ├── migrations/      # SQL (جداول + بيانات)
│   └── functions/       # Edge Functions (5 وظائف)
├── scripts/             # سكربتات البناء والإعداد
├── .env.example         # قالب متغيرات البيئة
└── SETUP_GUIDE.md       # هذا الدليل
```
