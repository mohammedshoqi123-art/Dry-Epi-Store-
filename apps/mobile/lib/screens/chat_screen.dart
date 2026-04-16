import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:epi_core/epi_core.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isConfigured = false;
  bool _showEmoji = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserAvatar;
  Timer? _pollTimer;
  Timer? _typingTimer;

  // Typing indicator animation
  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _isConfigured = SupabaseConfig.isConfigured;
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    if (_isConfigured) {
      _initUser();
      _loadMessages();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _loadMessages(silent: true),
      );
    } else {
      _isLoading = false;
    }
  }

  void _initUser() {
    try {
      final client = Supabase.instance.client;
      _currentUserId = client.auth.currentUser?.id;
      _currentUserName =
          client.auth.currentUser?.userMetadata?['full_name'] ??
              client.auth.currentUser?.email?.split('@').first ??
              'مستخدم';
      _currentUserAvatar = _currentUserName
          ?.substring(0, math.min(2, _currentUserName!.length))
          .toUpperCase();
    } catch (_) {
      _currentUserName = 'مستخدم';
      _currentUserAvatar = 'م';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _typingAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!_isConfigured) return;
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('chat_messages')
          .select('*')
          .eq('room', 'general')
          .order('created_at', ascending: true)
          .limit(200);

      if (mounted) {
        setState(() {
          _messages = (response as List).cast<Map<String, dynamic>>();
          if (!silent) _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isConfigured) return;

    setState(() => _isSending = true);
    _messageController.clear();

    HapticFeedback.lightImpact();

    try {
      final client = Supabase.instance.client;
      await client.from('chat_messages').insert({
        'sender_id': _currentUserId,
        'sender_name': _currentUserName,
        'content': text,
        'room': 'general',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        _messageController.text = text; // restore text on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('فشل الإرسال — حاول مرة أخرى',
                    style: TextStyle(fontFamily: 'Tajawal')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Date grouping helpers ───────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'اليوم';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'أمس';
    }
    return DateFormat('d MMMM yyyy', 'ar').format(date);
  }

  bool _shouldShowAvatar(int index) {
    if (index == _messages.length - 1) return true;
    final current = _messages[index];
    final next = _messages[index + 1];
    return current['sender_id'] != next['sender_id'];
  }

  bool _shouldShowName(int index) {
    if (index == 0) return true;
    final current = _messages[index];
    final prev = _messages[index - 1];
    return current['sender_id'] != prev['sender_id'];
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current =
        DateTime.tryParse(_messages[index]['created_at'] ?? '') ??
            DateTime.now();
    final prev =
        DateTime.tryParse(_messages[index - 1]['created_at'] ?? '') ??
            DateTime.now();
    return !_isSameDay(current, prev);
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !_isConfigured ? _buildNotConfigured() : _buildChatBody(),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Messages
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessagesList(),
        ),

        // Input
        _buildInputBar(),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // Title & status
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الشات الداخلي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    // Pulse dot
                    _PulseDot(),
                    SizedBox(width: 6),
                    Text(
                      'متصل — تحديث تلقائي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          _headerAction(Icons.refresh_rounded, () => _loadMessages()),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─── Messages List ──────────────────────────────────────────────────

  Widget _buildMessagesList() {
    // Build list items with date separators
    final items = <Widget>[];

    for (int i = 0; i < _messages.length; i++) {
      // Date separator
      if (_shouldShowDateSeparator(i)) {
        final date =
            DateTime.tryParse(_messages[i]['created_at'] ?? '') ??
                DateTime.now();
        items.add(_dateSeparator(_dateLabel(date)));
      }

      final msg = _messages[i];
      final isMe = msg['sender_id'] == _currentUserId;
      final showAvatar = _shouldShowAvatar(i);
      final showName = _shouldShowName(i);

      items.add(_buildMessageBubble(msg, isMe, showAvatar, showName));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: items,
    );
  }

  Widget _dateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }

  // ─── Message Bubble ─────────────────────────────────────────────────

  Widget _buildMessageBubble(
      Map<String, dynamic> msg, bool isMe, bool showAvatar, bool showName) {
    final createdAt =
        DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final senderName = msg['sender_name'] ?? 'مستخدم';
    final avatarInitial = senderName.isNotEmpty
        ? senderName.substring(0, math.min(2, senderName.length))
        : '؟';

    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 12 : 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe)
            showAvatar
                ? _avatar(avatarInitial, _avatarColor(senderName))
                : const SizedBox(width: 36),

          const SizedBox(width: 6),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name
                if (!isMe && showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 8),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _avatarColor(senderName),
                      ),
                    ),
                  ),

                // The bubble itself
                GestureDetector(
                  onLongPress: () => _showMessageOptions(msg, isMe),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF00897B)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 16 : 4),
                        topRight: Radius.circular(isMe ? 4 : 16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isMe ? 0.12 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          msg['content'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14.5,
                            height: 1.5,
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF1A2332),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white
                                        .withValues(alpha: 0.65)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: Colors.white
                                    .withValues(alpha: 0.65),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initials, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF00897B),
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
      const Color(0xFF7E57C2),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFFFA726),
      const Color(0xFFEF5350),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            _optionTile(Icons.copy_rounded, 'نسخ الرسالة', () {
              Clipboard.setData(
                  ClipboardData(text: msg['content'] ?? ''));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم النسخ!',
                      style: TextStyle(fontFamily: 'Tajawal')),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }),
            if (isMe)
              _optionTile(Icons.delete_outline_rounded, 'حذف', () {
                Navigator.pop(context);
                _deleteMessage(msg['id']);
              }, color: const Color(0xFFEF4444)),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {Color color = const Color(0xFF6B7280)}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              fontFamily: 'Tajawal', color: color, fontSize: 14)),
      onTap: onTap,
      horizontalTitleGap: 8,
    );
  }

  Future<void> _deleteMessage(dynamic id) async {
    if (id == null) return;
    try {
      final client = Supabase.instance.client;
      await client.from('chat_messages').delete().eq('id', id);
      await _loadMessages(silent: true);
    } catch (_) {}
  }

  // ─── Input Bar ───────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Send button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _messageController.text.trim().isNotEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF00695C)],
                      )
                    : null,
                color: _messageController.text.trim().isNotEmpty
                    ? null
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color:
                          _messageController.text.trim().isNotEmpty
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  color: Color(0xFF1A2332),
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Color(0xFF9CA3AF), size: 22),
                    onPressed: () {
                      // Emoji picker placeholder
                    },
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── States ──────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: const Color(0xFF00897B).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'جاري تحميل الرسائل...',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFED7AA).withValues(alpha: 0.5),
                    const Color(0xFFFED7AA).withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 56, color: Color(0xFFF97316)),
            ),
            const SizedBox(height: 28),
            const Text(
              'الشات غير متاح',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'يتطلب الاتصال بخادم Supabase\nللرسائل الفورية بين أعضاء الفريق',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated illustration
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00897B).withValues(alpha: 0.1),
                      const Color(0xFF00897B).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 52, color: Color(0xFF00897B)),
                    Positioned(
                      top: 25,
                      right: 25,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'ابدأ المحادثة! 💬',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'كن أول من يرسل رسالة في هذه المحادثة\nستظهر الرسائل هنا فور إرسالها',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            // Suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('مرحباً بالفريق 👋'),
                _suggestionChip('السلام عليكم 🤝'),
                _suggestionChip('شكراً لكم 🙏'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00897B).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            color: Color(0xFF00695C),
          ),
        ),
      ),
    );
  }
}

// ─── Pulse Dot Animation ─────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981)
                    .withValues(alpha: 0.4 * _controller.value),
                blurRadius: 6 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
