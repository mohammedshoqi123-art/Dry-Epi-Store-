# 📖 دليل الإعداد الشامل — منصة مشرف EPI

> هذا الدليل يشرح كيفية إعداد المنصة من الصفر على بيئة إنتاج.

---

## 📋 المتطلبات الأساسية

### الأدوات المطلوبة

| الأداة | الإصدار المطلوب | رابط التحميل | ملاحظة |
|--------|-----------------|-------------|--------|
| Git | 2.30+ | [git-scm.com](https://git-scm.com) | إدارة الكود |
| Flutter SDK | 3.19+ | [flutter.dev](https://flutter.dev/get-started/install) | إطار العمل الرئيسي |
| Dart SDK | 3.3+ | مرفق مع Flutter | لغة البرمجة |
| Node.js | 18+ | [nodejs.org](https://nodejs.org) | لـ Supabase CLI |
| Supabase CLI | أحدث | `npm install -g supabase` | إدارة قاعدة البيانات |
| Android Studio | أحدث | [developer.android.com](https://developer.android.com/studio) | لبناء APK |

### الحسابات المطلوبة

| الخدمة | الهدف | الرابط | مجاني؟ |
|--------|-------|--------|--------|
| Supabase | Backend + Auth + DB | [supabase.com](https://supabase.com) | ✅ حتى 50K مستخدم |
| GitHub | استضافة الكود | [github.com](https://github.com) | ✅ |
| MiMo AI | المساعد الذكي | [api.xiaomimimo.com](https://api.xiaomimimo.com) | حسب الاستخدام |
| Sentry | مراقبة الأخطاء | [sentry.io](https://sentry.io) | ✅ حتى 5K حدث/شهر |

---

## 🚀 خطوات الإعداد

### الخطوة 1: استنساخ المشروع

```bash
git clone https://github.com/mohammedshoqi123-art/EPI-Supervisor.git
cd EPI-Supervisor
```

### الخطوة 2: إعداد Supabase

#### 2.1 إنشاء مشروع Supabase

1. اذهب إلى [supabase.com/dashboard](https://supabase.com/dashboard)
2. اضغط **New Project**
3. اختر المنطقة الأقرب لليمن (مثل: `Southeast Asia (Singapore)`)
4. احفظ **Project URL** و **Anon Key** و **Service Role Key**

#### 2.2 ربط المشروع

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

#### 2.3 تطبيق هيكل قاعدة البيانات

```bash
# تطبيق الجداول + RLS + الدوال
supabase db push

# أو يدوياً عبر Supabase Dashboard → SQL Editor:
# 1. انسخ محتوى supabase/migrations/001_schema.sql وشغّله
# 2. انسخ محتوى supabase/migrations/002_seed_data.sql وشغّله
```

#### 2.4 نشر Edge Functions

```bash
cd supabase/functions
supabase functions deploy
```

#### 2.5 إعداد متغيرات Edge Functions

في Supabase Dashboard → **Edge Functions** → **Secrets**:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
MIMO_API_KEY=your-mimo-api-key
ALLOWED_ORIGINS=https://your-domain.com,http://localhost:5173
ENCRYPTION_KEY=<أنشئ مفتاح عشوائي: openssl rand -base64 32>
CREATE_ADMIN_SECRET=<أنشئ كلمة سر عشوائية>
```

> ⚠️ **تحذيرات أمنية:**
> - لا تضع `*` في `ALLOWED_ORIGINS` في الإنتاج
> - `ENCRYPTION_KEY` يجب أن يكون 32 حرف على الأقل
> - لا تشارك `SERVICE_ROLE_KEY` أبداً

### الخطوة 3: إعداد التطبيق المحمول

#### 3.1 تثبيت التبعيات

```bash
cd apps/mobile
flutter pub get
```

#### 3.2 إنشاء ملف البيئة

```bash
cp ../../.env.example ../../.env
# عدّل القيم في .env
```

#### 3.3 تشغيل التطبيق

```bash
# على Android (جهاز أو محاكي)
flutter run \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key" \
  --dart-define=ENCRYPTION_KEY="your-encryption-key"

# على الويب
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key" \
  --dart-define=ENCRYPTION_KEY="your-encryption-key"
```

#### 3.4 بناء APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key" \
  --dart-define=ENCRYPTION_KEY="your-encryption-key"
```

سيكون الملف في: `build/app/outputs/flutter-apk/app-release.apk`

### الخطوة 4: إعداد لوحة الويب (Admin Panel)

```bash
cd apps/admin-web
cp .env.example .env
# عدّل VITE_SUPABASE_URL و VITE_SUPABASE_ANON_KEY

npm install
npm run dev     # تشغيل محلي
npm run build   # بناء للإنتاج
```

---

## 👤 إنشاء أول مستخدم (المدير)

### الطريقة 1: عبر Edge Function

```bash
curl -X POST https://your-project.supabase.co/functions/v1/create-admin \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SERVICE_ROLE_KEY" \
  -d '{
    "email": "admin@epi.gov.ye",
    "password": "StrongPassword123!",
    "full_name": "مدير النظام",
    "secret": "YOUR_CREATE_ADMIN_SECRET"
  }'
```

### الطريقة 2: عبر Supabase Dashboard

1. اذهب إلى **Authentication** → **Users** → **Add User**
2. أدخل البريد وكلمة المرور
3. اذهب إلى **SQL Editor** وشغّل:

```sql
INSERT INTO profiles (id, email, full_name, role)
SELECT id, email, 'مدير النظام', 'admin'
FROM auth.users
WHERE email = 'admin@epi.gov.ye'
ON CONFLICT (id) DO UPDATE SET role = 'admin';
```

---

## 🔧 إعداد Monorepo (melos)

```bash
dart pub global activate melos
melos bootstrap    # تثبيت كل التبعيات
melos analyze      # تحليل الكود
melos test         # تشغيل الاختبارات
melos build_apk    # بناء APK
```

---

## 🧪 الاختبارات

```bash
cd apps/mobile

# تشغيل كل الاختبارات
flutter test --coverage

# تشغيل اختبارات وحدة محددة
flutter test test/unit/encryption_test.dart

# تشغيل اختبارات الواجهة
flutter test test/widget/login_screen_test.dart
```

---

## 🔄 CI/CD

### GitHub Actions (مُعد مسبقاً)

الـ Pipeline يعمل تلقائياً عند Push على `main`:

1. **Analyze & Test** — تحليل الكود + تشغيل الاختبارات
2. **Build APK** — بناء تطبيق Android
3. **Build Web** — بناء تطبيق الويب
4. **Deploy Pages** — نشر لوحة الويب على GitHub Pages
5. **Deploy Functions** — نشر Edge Functions

### متطلبات GitHub Secrets

في GitHub → **Settings** → **Secrets**:

| Secret | القيمة |
|--------|--------|
| `SUPABASE_ACCESS_TOKEN` | من Supabase Dashboard |
| `SUPABASE_PROJECT_REF` | مرجع المشروع |
| `SUPABASE_DB_PASSWORD` | كلمة مرور قاعدة البيانات |
| `SENTRY_DSN` | (اختياري) DSN من Sentry |

---

## 🛠️ استكشاف الأخطاء

### فشل `flutter pub get`
```bash
# مسح الكاش
flutter clean
flutter pub cache repair
flutter pub get
```

### فشل الاتصال بـ Supabase
```bash
# تحقق من متغيرات البيئة
echo $SUPABASE_URL
echo $SUPABASE_ANON_KEY

# تحقق من RLS
# في Supabase Dashboard → Authentication → Policies
```

### فشل Edge Functions
```bash
# عرض السجلات
supabase functions logs ai-chat --tail

# إعادة النشر
supabase functions deploy ai-chat --no-verify-jwt
```

### فشل البناء في CI
```bash
# تحقق من إصدار Flutter
cat .github/workflows/ci.yml | grep FLUTTER_VERSION

# تحقق من الأخطاء محلياً أولاً
flutter analyze
flutter test
```

---

## 📞 الدعم

- **Issues**: [github.com/mohammedshoqi123-art/EPI-Supervisor/issues](https://github.com/mohammedshoqi123-art/EPI-Supervisor/issues)
- **البريد**: mohammedshoqi123-art

---

<div align="center">

**منصة مشرف EPI v2.1.0** | Built with ❤️

</div>
