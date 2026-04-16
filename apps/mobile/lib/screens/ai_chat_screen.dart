import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class ChatMessage {
  final String role;
  final String content;
  const ChatMessage({required this.role, required this.content});
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {String? mode, String? template}) async {
    if (text.trim().isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      if (mode == null && template == null) {
        _messages.add(ChatMessage(role: 'user', content: text));
      }
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final gemini = ref.read(geminiServiceProvider);
      final campaign = ref.read(campaignProvider);
      final analytics = ref.read(dashboardAnalyticsProvider(
        AnalyticsFilter(campaignType: campaign.value),
      ));
      Map<String, dynamic>? ctx;
      analytics.whenData((d) => ctx = d);

      // Include campaign context in the prompt
      final campaignPrefix = 'النشاط الحالي: ${campaign.labelAr}. ';
      final response = await gemini.chat(
        '$campaignPrefix$text',
        analyticsContext: ctx,
        mode: mode,
        template: template,
      );

      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: response));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: 'حدث خطأ: $e'));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 22),
            SizedBox(width: 8),
            Text('المساعد الذكي', style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
          ],
        ),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(() => _messages.clear()),
              tooltip: 'مسح المحادثة',
            ),
        ],
        bottom: _messages.isEmpty
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'اقتراحات'),
                  Tab(icon: Icon(Icons.description_rounded, size: 18), text: 'تقارير'),
                  Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'الدليل'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Quick actions bar (always visible)
          if (_messages.isEmpty) Expanded(child: _buildWelcomeTabs()),
          if (_messages.isNotEmpty) Expanded(child: _buildMessages()),

          // Loading indicator
          if (_isLoading) _buildLoadingBubble(),

          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WELCOME TABS
  // ═══════════════════════════════════════════════════════════
  Widget _buildWelcomeTabs() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildSuggestionsTab(),
        _buildReportTemplatesTab(),
        _buildGuideTab(),
      ],
    );
  }

  // TAB 1: Smart Suggestions
  Widget _buildSuggestionsTab() {
    final suggestions = [
      _Sugg('📊', 'ما حالة الإرساليات اليوم؟', 'كم إرسالية أُرسلت اليوم وما نسبتها؟'),
      _Sugg('⚠️', 'أين النواقص الحرجة؟', 'حدد النواقص الحرجة ومستوى الخطورة'),
      _Sugg('📈', 'اعرض تقرير أسبوعي', 'تحليل اتجاه الأسبوع الحالي'),
      _Sugg('🗺️', 'أي المحافظات تحتاج دعم؟', 'ترتيب المحافظات بالأداء'),
      _Sugg('💉', 'ما تغطية التطعيم؟', 'تحليل Penta3 ونسبة الانسحاب'),
      _Sugg('✅', 'حلل جودة الإدخال', 'نسبة الرفض واكتمال الحقول'),
      _Sugg('🔄', 'قارن الأسبوع الحالي بالسابق', 'نسب تغيير الإرساليات'),
      _Sugg('👥', 'تقييم أداء المشرفين', 'عدد وجودة الإرساليات لكل مشرف'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // AI Avatar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 48, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 12),
          const Text('كيف أساعدك اليوم؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('اختر اقتراحاً أو اكتب سؤالك', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),

          // Suggestion cards
          ...suggestions.map((s) => _buildSuggestionCard(s)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(_Sugg s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            _sendMessage(s.question);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(s.emoji, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.question, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s.hint, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TAB 2: Report Templates
  Widget _buildReportTemplatesTab() {
    final templates = [
      _Template('daily', '📅', 'التقرير اليومي', 'ملخص شامل ليوم العمل'),
      _Template('weekly', '📊', 'التقرير الأسبوعي', 'تحليل اتجاه الأسبوع'),
      _Template('governorate', '🗺️', 'تقرير المحافظات', 'مقارنة أداء المحافظات'),
      _Template('shortages', '⚠️', 'تقرير النواقص', 'تحليل النواقص والحلول'),
      _Template('quality', '✅', 'تقرير جودة البيانات', 'اكتمال ودقة الإدخال'),
      _Template('comparison', '🔄', 'تقرير مقارنة', 'مقارنة فترتين زمنيتين'),
      _Template('coverage', '💉', 'تقرير التغطية', 'تغطية التطعيمات وفجوات'),
      _Template('field_performance', '👥', 'تقييم الميدانيين', 'أداء المشرفين الميدانيين'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝 اختر قالب تقرير', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('سيتم إنشاء التقرير تلقائياً بناءً على البيانات الحالية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: templates.length,
            itemBuilder: (context, i) => _buildTemplateCard(templates[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(_Template t) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _sendMessage('أنشئ ${t.name}', template: t.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(t.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(t.description, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 3: Usage Guide
  Widget _buildGuideTab() {
    final guides = [
      _Guide('📝', 'كيف أملأ استمارة؟', 'fill_a_form'),
      _Guide('📊', 'كيف أشاهد التحليلات؟', 'view_analytics'),
      _Guide('🗺️', 'كيف أستخدم الخريطة؟', 'use_map'),
      _Guide('📤', 'كيف أُصدّر تقرير PDF؟', 'export_pdf'),
      _Guide('📡', 'العمل بدون إنترنت', 'offline_mode'),
      _Guide('👥', 'إدارة المستخدمين', 'manage_users'),
      _Guide('🔔', 'إعداد الإشعارات', 'setup_notifications'),
      _Guide('🔄', 'المزامنة اليدوية', 'manual_sync'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📖 دليل الاستخدام', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('اسألني عن أي ميزة وسأشرحها لك', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ...guides.map((g) => _buildGuideTile(g)),
          const SizedBox(height: 16),
          // Direct link to full guide
          Material(
            color: AppTheme.secondaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _sendMessage('أرني الدليل الكامل للمنصة'),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, color: AppTheme.secondaryColor, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('الدليل الكامل (PDF)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600))),
                    Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppTheme.textHint),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTile(_Guide g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            _sendMessage('اشرح لي ${g.question}', mode: 'guide');
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(g.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(g.question, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w500))),
                const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════════
  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: SelectableText(
                msg.content,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primarySurface,
              child: Icon(Icons.person_rounded, size: 16, color: AppTheme.primaryColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
            child: const Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.secondaryColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryColor)),
                SizedBox(width: 8),
                Text('جارٍ التفكير...', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Guide button
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: AppTheme.secondaryColor),
              onPressed: () {
                if (_messages.isEmpty) {
                  _tabController.animateTo(2);
                } else {
                  _sendMessage('أحتاج مساعدة في استخدام المنصة');
                }
              },
              tooltip: 'الدليل',
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اسألني أي شيء...',
                  hintStyle: const TextStyle(fontFamily: 'Tajawal'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (text) => _sendMessage(text),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _isLoading ? Colors.grey : AppTheme.secondaryColor,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isLoading ? null : () => _sendMessage(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ Helper classes ═══
class _Sugg {
  final String emoji;
  final String question;
  final String hint;
  _Sugg(this.emoji, this.question, this.hint);
}

class _Template {
  final String id;
  final String emoji;
  final String name;
  final String description;
  _Template(this.id, this.emoji, this.name, this.description);
}

class _Guide {
  final String emoji;
  final String question;
  final String feature;
  _Guide(this.emoji, this.question, this.feature);
}
