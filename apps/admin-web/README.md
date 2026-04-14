# 🖥️ لوحة تحكم مشرف EPI — Admin Dashboard

لوحة تحكم ويب احترافية لإدارة منصة مشرف EPI، مبنية بأحدث التقنيات.

## التقنيات

| التقنية | الاستخدام |
|---------|----------|
| React 18 | واجهة المستخدم |
| Vite | البناء السريع |
| TypeScript | الأمان والتطوير |
| Tailwind CSS | التصميم |
| shadcn/ui | مكونات UI |
| Recharts | الرسوم البيانية |
| TanStack Query | إدارة البيانات |
| Supabase | الباك-إند |
| Lucide Icons | الأيقونات |
| Zustand | إدارة الحالة |

## التشغيل

```bash
cd apps/admin-web

# تثبيت الحزم
npm install

# نسخ ملف البيئة
cp .env.example .env
# عدّل القيم في .env

# تشغيل التطوير
npm run dev

# البناء للإنتاج
npm run build
```

## البنية

```
src/
├── components/
│   ├── ui/              # مكونات UI (Button, Card, Dialog, Table...)
│   ├── layout/          # Sidebar, Header, ThemeProvider
│   └── dashboard/       # مكونات لوحة التحكم
├── pages/               # الصفحات
│   ├── DashboardPage    # لوحة التحكم الرئيسية
│   ├── UsersPage        # إدارة المستخدمين
│   ├── FormsPage        # إدارة النماذج
│   ├── SubmissionsPage  # الإرساليات والمراجعة
│   ├── AnalyticsPage    # التحليلات والرسوم البيانية
│   ├── AuditPage        # سجل التدقيق
│   └── ShortagesPage    # تتبع النواقص
├── hooks/
│   └── useApi.ts        # hooks للبيانات (React Query)
├── lib/
│   ├── supabase.ts      # عميل Supabase
│   └── utils.ts         # دوال مساعدة
└── types/
    └── database.ts      # أنواع TypeScript
```

## المميزات

- ✅ **تصميم عربي RTL** كامل
- ✅ **الوضع الداكن** والفاتح
- ✅ **رسوم بيانية تفاعلية** (Area, Bar, Pie)
- ✅ **إدارة المستخدمين** (إضافة، تعديل، حذف، تفعيل/تعطيل)
- ✅ **مراجعة الإرساليات** (اعتماد/رفض)
- ✅ **تتبع النواقص** حسب الشدة
- ✅ **سجل تدقيق** كامل
- ✅ **استجابة للجوال** (Responsive)
- ✅ **تحميل تدريجي** مع Skeleton
- ✅ **.Toast إشعارات**
- ✅ **بحث وفلاتر** متقدمة
- ✅ **تصفح صفحات** (Pagination)
