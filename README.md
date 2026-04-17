<div align="center">

# 🏪 منصة مخزن EPI الجاف

### نظام إدارة المخازن الجافة للبرنامج الوطني للتحصين الصحي الموسع
*Dry Store Management for EPI Immunization Programme*

![Flutter](https://img.shields.io/badge/Flutter-3.27-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)
![React](https://img.shields.io/badge/React-Admin-61DAFB?style=for-the-badge&logo=react&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen?style=for-the-badge)

</div>

---

## 📋 نظرة عامة

**منصة مخزن EPI الجاف** هو نظام SaaS متكامل لإدارة المخازن الجافة الخاصة بالتطعيمات والمستلزمات الصحية في اليمن. يتتبع حركة المخزون من استلام إلى توزيع مع تنبيهات ذكية وتقارير احترافية.

### المميزات الرئيسية

- 📦 **إدارة المخزون** — تتبع الكميات والتواريخ الصلاحية + QR Code
- 🔄 **حركات المخزون** — استلام / صرف / تحويل بين المخازن
- ⚠️ **تنبيهات ذكية** — نقص مخزون + اقتراب انتهاء صلاحية
- 📊 **تقارير PDF** — استهلاك، مخزون، توزيع جغرافي
- 📡 **عمل بدون إنترنت** — مزامنة تلقائية
- 🗺️ **خرائط المخازن** — توزيع جغرافي
- 🤖 **مساعد AI** — تنبؤ بالطلب + توصيات
- 💬 **شات داخلي** — تواصل بين المستخدمين
- 📱 **تطبيق Flutter** — Android + iOS
- 🌐 **لوحة إدارة React** — إدارة مركزية

---

## 🏗️ البنية المعمارية

```
Dry-Epi-Store/
├── apps/
│   ├── mobile/              📱 تطبيق Flutter
│   └── admin-web/           🌐 لوحة إدارة (React)
├── packages/
│   ├── core/                🧠 منطق العمل (dry_core)
│   ├── shared/              🎨 مكونات UI (dry_shared)
│   └── features/            ⚡ ميزات متقدمة (dry_features)
├── supabase/
│   ├── functions/           ⚡ Edge Functions
│   └── migrations/          🗄️ قاعدة البيانات
├── scripts/                 🔧 سكريبتات
└── melos.yaml               📦 Monorepo
```

---

## 🚀 البدء السريع

```bash
git clone https://github.com/mohammedshoqi123-art/Dry-Epi-Store-.git
cd Dry-Epi-Store-
melos bootstrap
cd apps/mobile && flutter run
```

---

## 📱 الشاشات

| الشاشة | الوظيفة |
|--------|---------|
| 🏠 لوحة التحكم | KPIs — رسوم بيانية — إجراءات سريعة |
| 📦 المخزون | عرض الأرصدة — بحث — مسح QR |
| 🔄 الحركات | استلام / صرف / تحويل — حالة كل حركة |
| 🏪 المخازن | إدارة المخازن — السعة — الموقع |
| ⚠️ التنبيهات | نقص مخزون — صلاحية — تحويلات معلقة |
| 📊 التقارير | استهلاك — مخزون — توزيع جغرافي — PDF |
| 🤖 مساعد AI | تنبؤ بالطلب — توصيات ذكية |

---

## 🗄️ قاعدة البيانات

- **12 جدول** مع RLS كامل
- **22 محافظة** يمنية كبيانات أساسية
- **8 فئات** أصناف (لقاحات، محاقن، مستلزمات...)
- **تنبيهات تلقائية** عند نقص المخزون أو انتهاء الصلاحية
- **سجل تدقيق** لكل العمليات

---

**الإصدار:** 1.0.0
