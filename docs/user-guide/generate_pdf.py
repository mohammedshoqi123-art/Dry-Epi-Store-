from fpdf import FPDF
import arabic_reshaper
from bidi.algorithm import get_display
import os

def reshape_ar(text):
    """Reshape Arabic text for proper rendering"""
    reshaped = arabic_reshaper.reshape(text)
    return get_display(reshaped)

class EPIDoc(FPDF):
    def __init__(self):
        super().__init__()
        self.add_font('Arial', '', '/usr/share/fonts/truetype/msttcorefonts/Arial.ttf', uni=True)
        self.add_font('Arial', 'B', '/usr/share/fonts/truetype/msttcorefonts/arialbd.ttf', uni=True)
        self.set_auto_page_break(auto=True, margin=20)
        self.set_right_margin(15)
        self.set_left_margin(15)
        
    def header(self):
        if self.page_no() > 1:
            self.set_font('Arial', '', 8)
            self.set_text_color(150, 150, 150)
            self.cell(0, 10, reshape_ar('منصة مشرف EPI — دليل الاستخدام'), align='R', new_x='LMARGIN', new_y='NEXT')
            self.line(15, 15, self.w - 15, 15)
            self.ln(5)
    
    def footer(self):
        self.set_y(-15)
        self.set_font('Arial', '', 8)
        self.set_text_color(150, 150, 150)
        if self.page_no() > 1:
            self.cell(0, 10, f'{self.page_no()}', align='C')

    def cover_page(self):
        self.add_page()
        self.ln(50)
        # Icon
        self.set_font('Arial', '', 40)
        self.cell(0, 20, '\U0001F489', align='C', new_x='LMARGIN', new_y='NEXT')
        self.ln(10)
        # Title
        self.set_font('Arial', 'B', 28)
        self.set_text_color(13, 71, 161)
        self.cell(0, 15, reshape_ar('دليل استخدام منصة مشرف EPI'), align='C', new_x='LMARGIN', new_y='NEXT')
        self.ln(5)
        # Subtitle
        self.set_font('Arial', '', 14)
        self.set_text_color(100, 100, 100)
        self.cell(0, 10, reshape_ar('EPI Supervisor Platform — User Guide'), align='C', new_x='LMARGIN', new_y='NEXT')
        self.ln(15)
        # Version
        self.set_font('Arial', '', 12)
        self.set_text_color(30, 136, 229)
        self.cell(0, 10, reshape_ar('الإصدار 1.0.0 | أبريل 2026'), align='C', new_x='LMARGIN', new_y='NEXT')
        self.ln(10)
        self.set_font('Arial', '', 11)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, reshape_ar('نظام إشراف ميداني متكامل لحملات التطعيم'), align='C', new_x='LMARGIN', new_y='NEXT')
        self.cell(0, 8, reshape_ar('Field Supervision System for Immunization Campaigns'), align='C', new_x='LMARGIN', new_y='NEXT')

    def section_title(self, title):
        self.ln(5)
        self.set_font('Arial', 'B', 18)
        self.set_text_color(13, 71, 161)
        self.cell(0, 12, reshape_ar(title), align='R', new_x='LMARGIN', new_y='NEXT')
        self.set_draw_color(30, 136, 229)
        self.line(self.w - 15, self.get_y(), self.w - 80, self.get_y())
        self.ln(8)
    
    def sub_title(self, title):
        self.ln(3)
        self.set_font('Arial', 'B', 14)
        self.set_text_color(21, 101, 192)
        self.cell(0, 10, reshape_ar(title), align='R', new_x='LMARGIN', new_y='NEXT')
        self.ln(2)

    def body_text(self, text):
        self.set_font('Arial', '', 11)
        self.set_text_color(26, 26, 46)
        self.multi_cell(0, 7, reshape_ar(text), align='R')
        self.ln(2)

    def step(self, num, text):
        self.set_font('Arial', 'B', 11)
        self.set_text_color(13, 71, 161)
        x = self.get_x()
        y = self.get_y()
        self.cell(12, 7, f'{num}.', align='R')
        self.set_font('Arial', '', 11)
        self.set_text_color(26, 26, 46)
        self.multi_cell(0, 7, reshape_ar(text), align='R')
        self.ln(1)

    def info_box(self, text):
        self.set_fill_color(227, 242, 253)
        self.set_draw_color(21, 101, 192)
        y = self.get_y()
        self.rect(15, y, self.w - 30, 12, style='DF')
        self.set_xy(20, y + 2)
        self.set_font('Arial', '', 10)
        self.set_text_color(21, 101, 192)
        self.cell(0, 8, reshape_ar(f'💡 {text}'), align='R')
        self.set_y(y + 15)

    def warn_box(self, text):
        self.set_fill_color(255, 243, 224)
        self.set_draw_color(230, 81, 0)
        y = self.get_y()
        self.rect(15, y, self.w - 30, 12, style='DF')
        self.set_xy(20, y + 2)
        self.set_font('Arial', '', 10)
        self.set_text_color(230, 81, 0)
        self.cell(0, 8, reshape_ar(f'⚠️ {text}'), align='R')
        self.set_y(y + 15)

    def success_box(self, text):
        self.set_fill_color(232, 245, 233)
        self.set_draw_color(46, 125, 50)
        y = self.get_y()
        self.rect(15, y, self.w - 30, 12, style='DF')
        self.set_xy(20, y + 2)
        self.set_font('Arial', '', 10)
        self.set_text_color(46, 125, 50)
        self.cell(0, 8, reshape_ar(f'✅ {text}'), align='R')
        self.set_y(y + 15)

    def add_table(self, headers, rows):
        self.ln(3)
        col_w = (self.w - 30) / len(headers)
        # Header
        self.set_font('Arial', 'B', 10)
        self.set_fill_color(13, 71, 161)
        self.set_text_color(255, 255, 255)
        for h in headers:
            self.cell(col_w, 8, reshape_ar(h), border=1, fill=True, align='C')
        self.ln()
        # Rows
        self.set_font('Arial', '', 10)
        self.set_text_color(26, 26, 46)
        for i, row in enumerate(rows):
            if i % 2 == 0:
                self.set_fill_color(248, 250, 253)
            else:
                self.set_fill_color(255, 255, 255)
            for val in row:
                self.cell(col_w, 7, reshape_ar(val), border=1, fill=True, align='C')
            self.ln()
        self.ln(5)


def main():
    pdf = EPIDoc()
    
    # ═══ COVER ═══
    pdf.cover_page()
    
    # ═══ TOC ═══
    pdf.add_page()
    pdf.section_title('📑 فهرس المحتويات')
    toc = [
        '1. نظرة عامة على المنصة',
        '2. تسجيل الدخول والحساب',
        '3. لوحة التحكم الرئيسية',
        '4. ملء النماذج الميدانية',
        '5. عرض الإرساليات',
        '6. لوحة التحليلات',
        '7. المساعد الذكي AI',
        '8. الخريطة التفاعلية',
        '9. إدارة المستخدمين (للمدير)',
        '10. إدارة النماذج (للمدير)',
        '11. العمل بدون إنترنت',
        '12. نظام الصلاحيات',
        '13. الإشعارات',
        '14. استكشاف الأخطاء وحلها',
    ]
    for item in toc:
        pdf.set_font('Arial', '', 12)
        pdf.set_text_color(26, 26, 46)
        pdf.cell(0, 8, reshape_ar(item), align='R', new_x='LMARGIN', new_y='NEXT')

    # ═══ SECTION 1 ═══
    pdf.add_page()
    pdf.section_title('1. نظرة عامة على المنصة')
    pdf.body_text('منصة مشرف EPI هي نظام متكامل لإدارة والإشراف على حملات التطعيم الميدانية. تم تصميمها خصيصاً للعمل في بيئات قد تكون فيها الاتصال بالإنترنت محدوداً أو غير متاح.')
    pdf.sub_title('المميزات الرئيسية')
    pdf.add_table(
        ['الميزة', 'الوصف'],
        [
            ['📝 نماذج ديناميكية', 'محرك JSON Schema قابل للتخصيص'],
            ['📡 عمل بدون إنترنت', 'املأ النماذج واحفظها محلياً — تُزامن تلقائياً'],
            ['📊 تحليلات فورية', 'KPIs ورسوم بيانية وتقارير PDF/CSV'],
            ['🤖 ذكاء اصطناعي', 'مساعد MiMo للتحليل باللغة العربية'],
            ['🗺️ خرائط تفاعلية', 'تتبع المواقع مع clustering'],
            ['🔐 أمان متقدم', '5 مستويات صلاحيات + تشفير AES-256'],
        ]
    )
    pdf.sub_title('الفئات المستهدفة')
    for i, t in enumerate([
        'مدخلو البيانات — ملء النماذج الميدانية وإرسال التقارير',
        'مشرفو المديريات — مراجعة الإرساليات ومراقبة الأداء',
        'مشرفو المحافظات — الإشراف على جميع مديريات المحافظة',
        'المشرف المركزي — مراقبة الأداء على مستوى الجمهورية',
        'مدير النظام — إدارة المستخدمين والنماذج والإعدادات',
    ], 1):
        pdf.step(i, t)

    # ═══ SECTION 2 ═══
    pdf.add_page()
    pdf.section_title('2. تسجيل الدخول والحساب')
    pdf.body_text('يتم تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور التي يوفرها مدير النظام.')
    for i, t in enumerate([
        'افتح التطبيق — ستظهر شاشة الترحيب ثم تنتقل لشاشة تسجيل الدخول',
        'أدخل البريد الإلكتروني الذي سجّل لك من قبل مدير النظام',
        'أدخل كلمة المرور واضغط على تسجيل الدخول',
        'ستنتقل تلقائياً للوحة التحكم حسب صلاحياتك',
    ], 1):
        pdf.step(i, t)
    pdf.warn_box('إذا نسيت كلمة المرور، تواصل مع مدير النظام لإعادة تعيينها.')

    # ═══ SECTION 3 ═══
    pdf.add_page()
    pdf.section_title('3. لوحة التحكم الرئيسية')
    pdf.body_text('بعد تسجيل الدخول، تظهر لوحة التحكم التي تعرض ملخص أداء حملات التطعيم.')
    pdf.body_text('• البطاقات الإحصائية العلوية: تعرض أعداد الإرساليات اليوم ونسبة الإنجاز')
    pdf.body_text('• الرسوم البيانية: توضح توزيع التطعيمات حسب المحافظة')
    pdf.body_text('• قائمة التنقل السفلية: تتيح الانتقال السريع بين أقسام التطبيق')

    # ═══ SECTION 4 ═══
    pdf.add_page()
    pdf.section_title('4. ملء النماذج الميدانية')
    pdf.body_text('هذه الوظيفة الأساسية للمنصة — ملء نماذج التطعيم الميدانية وإرسالها.')
    for i, t in enumerate([
        'افتح قسم النماذج من القائمة السفلية أو الجانبية',
        'اختر النموذج المطلوب من القائمة (مثل: تقرير التطعيم اليومي)',
        'املأ الحقول — النموذج مقسم لأقسام (بيانات الطفل، نوع التطعيم، الموقع)',
        'أرفق الصور إن وُجدت (التقط من الكاميرا أو اختر من المعرض)',
        'راجع البيانات وتأكد من صحتها',
        'اضغط إرسال — يُحفظ محلياً أولاً ثم يُرسل للسيرفر',
    ], 1):
        pdf.step(i, t)
    pdf.success_box('البيانات تُحفظ فوراً على الجهاز حتى بدون إنترنت. لن تفقد أي بيانات!')
    pdf.info_box('يمكنك الضغط على حفظ كمسودة إذا لم تنتهِ من الملء.')

    # ═══ SECTION 5 ═══
    pdf.add_page()
    pdf.section_title('5. عرض الإرساليات')
    pdf.body_text('يعرض هذا القسم جميع النماذج التي تم إرسالها مع حالة كل إرسالية.')
    pdf.add_table(
        ['الحالة', 'الوصف'],
        [
            ['🟢 مُرسلة', 'تم إرسالها بنجاح والسيرفر استلمها'],
            ['🟡 قيد المراجعة', 'بانتظار موافقة المشرف'],
            ['✅ مُعتمدة', 'تمت الموافقة عليها من المشرف'],
            ['🔴 مرفوضة', 'تم رفضها مع سبب الرفض'],
            ['⏳ في الانتظار', 'لم تُزامن بعد (بدون إنترنت)'],
        ]
    )
    pdf.sub_title('الموافقة والرفض (للمشرفين)')
    pdf.step(1, 'اضغط على الإرسالية لعرض التفاصيل')
    pdf.step(2, 'راجع البيانات والموقع والصور المرفقة')
    pdf.step(3, "اضغط 'اعتماد' للقبول أو 'رفض' مع كتابة السبب")

    # ═══ SECTION 6 ═══
    pdf.add_page()
    pdf.section_title('6. لوحة التحليلات')
    pdf.body_text('توفر التحليلات نظرة شاملة على أداء حملات التطعيم مع رسوم بيانية وتصدير التقارير.')
    pdf.add_table(
        ['المؤشر', 'الوصف'],
        [
            ['إجمالي التطعيمات', 'عدد التطعيمات حسب الفترة المحددة'],
            ['التوزيع الجغرافي', 'التطعيمات حسب المحافظة والمديرة'],
            ['نسبة الإنجاز', 'نسبة التطعيمات المكتملة من المستهدف'],
            ['حسب نوع التطعيم', 'توزيع التطعيمات حسب النوع'],
            ['حسب العمر', 'توزيع الفئات العمرية المستهدفة'],
        ]
    )
    pdf.sub_title('تصدير التقارير')
    for i, t in enumerate([
        "اضغط على زر 'تصدير' في أعلى شاشة التحليلات",
        'اختر صيغة التصدير: PDF أو CSV',
        'حدد الفترة الزمنية والمحافظة (إن أردت)',
        'سيتم تحميل الملف تلقائياً',
    ], 1):
        pdf.step(i, t)

    # ═══ SECTION 7 ═══
    pdf.add_page()
    pdf.section_title('7. المساعد الذكي AI')
    pdf.body_text('مساعد ذكي يدعم اللغة العربية للإجابة على استفساراتك حول بيانات التطعيم وتحليلها.')
    pdf.step(1, "افتح قسم 'الذكاء الاصطناعي' من القائمة")
    pdf.step(2, 'اكتب سؤالك باللغة العربية — مثلاً: كم عدد التطعيمات في تعز هذا الأسبوع؟')
    pdf.step(3, 'المساعد سيرد بالأرقام والتحليل مع روابط للبيانات التفصيلية')
    pdf.info_box("أمثلة: 'كم عدد التطعيمات في تعز؟' — 'ما نسبة الإنجاز؟' — 'أي المديريات تحتاج دعماً؟'")

    # ═══ SECTION 8 ═══
    pdf.add_page()
    pdf.section_title('8. الخريطة التفاعلية')
    pdf.body_text('تعرض الخريطة مواقع الإرساليات الجغرافية مع إمكانية التكبير والتصغير والتصفية.')
    pdf.add_table(
        ['الميزة', 'الوصف'],
        [
            ['📍 علامات المواقع', 'نقطة زرقاء لكل إرسالية بناءً على GPS'],
            ['🔢 التجميع', 'تجمع النقاط القريبة عند التصغير'],
            ['🌡️ خريطة الحرارة', 'ألوان توضح كثافة التطعيمات'],
            ['🔍 التصفية', 'تصفية حسب المحافظة ونوع التطعيم'],
            ['📋 تفاصيل النقطة', 'اضغط على أي نقطة لعرض التفاصيل'],
        ]
    )

    # ═══ SECTION 9 ═══
    pdf.add_page()
    pdf.section_title('9. إدارة المستخدمين (للمدير)')
    pdf.body_text('متاح فقط لدور admin و central. يمكنك إدارة حسابات المستخدمين وأدوارهم.')
    for i, t in enumerate([
        'اذهب إلى القائمة ← إدارة المستخدمين',
        "اضغط على 'إضافة مستخدم' (+)",
        'املأ البيانات: الاسم، البريد، كلمة المرور، الدور',
        'اختر المحافظة/المديرة حسب الدور',
        "اضغط 'حفظ'",
    ], 1):
        pdf.step(i, t)

    # ═══ SECTION 10 ═══
    pdf.add_page()
    pdf.section_title('10. إدارة النماذج (للمدير)')
    pdf.body_text('يمكن لمدير النظام إنشاء وتعديل النماذج الديناميكية التي يستخدمها مدخلو البيانات.')
    for i, t in enumerate([
        "اذهب إلى القائمة ← إدارة النماذج",
        "اضغط 'إنشاء نموذج جديد'",
        'أدخل اسم النموذج ووصفه',
        'أضف الحقول: نص، رقم، تاريخ، قائمة منسدلة، صورة، موقع GPS',
        "اضغط 'حفظ ونشر'",
    ], 1):
        pdf.step(i, t)
    pdf.info_box('أنواع الحقول: نص قصير، نص طويل، رقم، تاريخ، قائمة منسدلة، اختيار متعدد، صورة، GPS، توقيع')

    # ═══ SECTION 11 ═══
    pdf.add_page()
    pdf.section_title('11. العمل بدون إنترنت')
    pdf.body_text('المنصة مصممة بالكامل للعمل Offline-First — العمل بدون إنترنت هو الحالة الطبيعية.')
    for i, t in enumerate([
        'الحفظ المحلي أولاً — كل نموذج يُحفظ فوراً على جهازك',
        'طابور المزامنة — النماذج تنتظر بأولويات (التطعيمات أولاً)',
        'المزامنة التلقائية — عند عودة الإنترنت تُرسل كل 5 دقائق',
        'إعادة المحاولة — 10 ثواني ← 30 ثانية ← 90 ثانية ← 5 دقائق ← 15 دقيقة',
        'حل التعارضات — إذا عُدّل نفس السجل على جهازين يُدمج تلقائياً',
    ], 1):
        pdf.step(i, t)
    pdf.add_table(
        ['الرمز', 'الحالة', 'الوصف'],
        [
            ['🟢', 'متصل', 'كل شيء متزامن'],
            ['🟡', 'متصل مع تأخير', 'سجلات في الانتظار'],
            ['🔴', 'غير متصل', 'البيانات محفوظة محلياً'],
        ]
    )
    pdf.success_box('ضمان عدم فقدان البيانات: حتى لو انطفأ الجهاز — بياناتك آمنة.')

    # ═══ SECTION 12 ═══
    pdf.add_page()
    pdf.section_title('12. نظام الصلاحيات (RBAC)')
    pdf.body_text('المنصة تستخدم نظام صلاحيات هرمي بـ 5 مستويات. كل دور يرى ويفعل فقط ما يُسمح له.')
    pdf.add_table(
        ['الدور', 'المستوى', 'الصلاحيات'],
        [
            ['مدير النظام', '5', 'كل شيء: إدارة المستخدمين والنماذج'],
            ['مشرف مركزي', '4', 'رؤية كل البيانات وإدارة النماذج'],
            ['مشرف محافظة', '3', 'رؤية بيانات محافظته والموافقة'],
            ['مشرف مديرية', '2', 'رؤية بيانات مديريته فقط'],
            ['مدخل بيانات', '1', 'ملء النماذج ورؤية بياناته فقط'],
        ]
    )
    pdf.warn_box('مدخل البيانات لا يستطيع رؤية إرساليات الآخرين أو الموافقة/الرفض.')

    # ═══ SECTION 13 ═══
    pdf.add_page()
    pdf.section_title('13. الإشعارات')
    pdf.body_text('تستلم إشعارات عن الأحداث المهمة في المنصة.')
    pdf.add_table(
        ['النوع', 'الوصف'],
        [
            ['📤 تأكيد الإرسال', 'تم استلام نموذجك بنجاح'],
            ['✅ اعتماد', 'تمت الموافقة على إرساليتك'],
            ['❌ رفض', 'تم رفض إرساليتك — اضغط لرؤية السبب'],
            ['⚠️ نقص تجهيزات', 'تم الإبلاغ عن نقص في منطقة قريبة'],
            ['📢 إشعار النظام', 'تحديثات وإرشادات من الإدارة'],
        ]
    )

    # ═══ SECTION 14 ═══
    pdf.add_page()
    pdf.section_title('14. استكشاف الأخطاء وحلها')
    pdf.sub_title('لا أستطيع تسجيل الدخول')
    pdf.step(1, 'تأكد من صحة البريد الإلكتروني وكلمة المرور')
    pdf.step(2, 'تأكد من اتصالك بالإنترنت (تسجيل الدخول يتطلب إنترنت)')
    pdf.step(3, 'تواصل مع مدير النظام إذا استمرت المشكلة')
    pdf.sub_title('النماذج لا تُرسل')
    pdf.step(1, 'تحقق من مؤشر الاتصال — إذا 🔴 فالبيانات محفوظة وستُرسل عند عودة الإنترنت')
    pdf.step(2, 'تأكد من ملء جميع الحقول المطلوبة (الحقل المطلوب يظهر بـ *)')
    pdf.step(3, 'تحقق من تفعيل GPS إذا كان مطلوباً')
    pdf.sub_title('التطبيق بطيء')
    pdf.step(1, 'أغلق التطبيق وأعد فتحه')
    pdf.step(2, 'امسح ذاكرة التخزين المؤقت من إعدادات الجهاز')
    pdf.step(3, 'تأكد من وجود مساحة كافية على جهازك')
    pdf.info_box('الدعم الفني: support@epi-supervisor.com')

    # ═══ LAST PAGE ═══
    pdf.add_page()
    pdf.ln(80)
    pdf.set_font('Arial', '', 12)
    pdf.set_text_color(100, 100, 100)
    pdf.cell(0, 10, reshape_ar('منصة مشرف EPI — الإصدار 1.0.0'), align='C', new_x='LMARGIN', new_y='NEXT')
    pdf.cell(0, 10, reshape_ar('أبريل 2026'), align='C', new_x='LMARGIN', new_y='NEXT')
    pdf.cell(0, 10, reshape_ar('© جميع الحقوق محفوظة'), align='C', new_x='LMARGIN', new_y='NEXT')

    # Save
    output = '/root/.openclaw/workspace/EPI-Supervisor/docs/user-guide/EPI_Supervisor_User_Guide.pdf'
    pdf.output(output)
    print(f'✅ PDF generated: {output}')

if __name__ == '__main__':
    main()
