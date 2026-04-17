import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dry_shared/dry_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
// الدردشة الداخلية — Internal Chat (Enhanced)
// ══════════════════════════════════════════════════════════════════════════════

/// مزود القنوات
final chatChannelsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final response = await client
        .from('chat_channels')
        .select('*')
        .eq('is_active', true)
        .order('created_at');
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

// ─── Screen ────────────────────────────────────────────────────────────────

class InternalChatScreen extends ConsumerStatefulWidget {
  final String? channelId;
  final String? channelName;

  const InternalChatScreen({super.key, this.channelId, this.channelName});

  @override
  ConsumerState<InternalChatScreen> =>
      _InternalChatScreenState();
}

class _InternalChatScreenState extends ConsumerState<InternalChatScreen>
    with TickerProviderStateMixin {
  String? _activeChannelId;
  String? _activeChannelName;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _activeChannelId = widget.channelId;
    _activeChannelName = widget.channelName;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Color helpers ────────────────────────────────────────────────────

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

  String _avatarInitial(String name) {
    if (name.isEmpty) return '؟';
    return name.substring(0, math.min(2, name.length));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'اليوم';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'أمس';
    return DateFormat('d MMMM yyyy', 'ar').format(date);
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: _activeChannelId == null
            ? _buildChannelsView()
            : _buildChatView(),
      ),
    );
  }

  // ─── Channels View ────────────────────────────────────────────────────

  Widget _buildChannelsView() {
    return Column(
      children: [
        // Header
        _channelsHeader(),

        // Create button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateChannelDialog(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('إنشاء قناة جديدة',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),

        // Channels list
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final channelsAsync = ref.watch(chatChannelsProvider);

              return channelsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      const Text('فشل تحميل القنوات',
                          style: TextStyle(fontFamily: 'Tajawal')),
                    ],
                  ),
                ),
                data: (channels) {
                  if (channels.isEmpty) return _channelsEmpty();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      return _channelCard(ch);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _channelsHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدردشة الداخلية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'تواصل مع فريق العمل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelCard(Map<String, dynamic> ch) {
    final isAnnouncement = ch['is_announcement'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _activeChannelId = ch['id'];
              _activeChannelName = ch['name'];
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAnnouncement
                          ? [const Color(0xFFF59E0B), const Color(0xFFF97316)]
                          : [const Color(0xFF00897B), const Color(0xFF00695C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isAnnouncement
                        ? Icons.campaign_rounded
                        : Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch['name'] ?? 'قناة',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2332),
                        ),
                      ),
                      if (ch['description'] != null &&
                          ch['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            ch['description'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge
                if (isAnnouncement)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'إعلان',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFFD1D5DB),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _channelsEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00897B).withValues(alpha: 0.1),
                      const Color(0xFF00897B).withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_outlined,
                    size: 48, color: Color(0xFF00897B)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد قنوات بعد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أنشئ قناة لبدء التواصل مع الفريق',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chat View ────────────────────────────────────────────────────────

  Widget _buildChatView() {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id ?? '';

    return Column(
      children: [
        // Chat header
        _chatHeader(),

        // Messages
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: client
                .from('chat_messages')
                .stream(primaryKey: ['id'])
                .eq('channel_id', _activeChannelId!)
                .order('created_at', ascending: true)
                .limit(200),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                );
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) return _chatEmpty();

              // Auto-scroll
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              return _buildMessagesList(messages, currentUserId);
            },
          ),
        ),

        // Input
        _buildInputBar(),
      ],
    );
  }

  Widget _chatHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
        ),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => setState(() {
              _activeChannelId = null;
              _activeChannelName = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Channel info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeChannelName ?? 'قناة',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Row(
                  children: [
                    _ChatPulseDot(),
                    SizedBox(width: 6),
                    Text(
                      'متصل',
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
          // Members
          GestureDetector(
            onTap: () => _showChannelMembers(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_outline_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(
      List<Map<String, dynamic>> messages, String currentUserId) {
    final items = <Widget>[];

    for (int i = 0; i < messages.length; i++) {
      // Date separator
      if (i == 0 ||
          !_isSameDay(
            DateTime.tryParse(messages[i]['created_at'] ?? '') ??
                DateTime.now(),
            DateTime.tryParse(messages[i - 1]['created_at'] ?? '') ??
                DateTime.now(),
          )) {
        final date =
            DateTime.tryParse(messages[i]['created_at'] ?? '') ??
                DateTime.now();
        items.add(_dateSeparator(_dateLabel(date)));
      }

      final msg = messages[i];
      final isMe = msg['sender_id'] == currentUserId;
      final showAvatar = i == messages.length - 1 ||
          messages[i + 1]['sender_id'] != msg['sender_id'];
      final showName = i == 0 ||
          messages[i - 1]['sender_id'] != msg['sender_id'];

      items.add(_messageBubble(msg, isMe, showAvatar, showName));
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

  Widget _messageBubble(
      Map<String, dynamic> msg, bool isMe, bool showAvatar, bool showName) {
    final createdAt =
        DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final senderName = msg['sender_name'] ?? 'مستخدم';
    final avatarInitial = _avatarInitial(senderName);
    final color = _avatarColor(senderName);

    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 12 : 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          if (!isMe)
            showAvatar
                ? _avatar(avatarInitial, color)
                : const SizedBox(width: 36),
          const SizedBox(width: 6),

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Name
                if (!isMe && showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 8),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),

                // Bubble
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
                                msg['is_read'] == true
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                size: 14,
                                color: msg['is_read'] == true
                                    ? Colors.lightBlueAccent
                                    : Colors.white
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

  Widget _chatEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00897B).withValues(alpha: 0.1),
                      const Color(0xFF00897B).withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 44, color: Color(0xFF00897B)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ابدأ المحادثة! 💬',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'كن أول من يرسل رسالة في هذه القناة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Input Bar ────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Send
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _messageController.text.trim().isNotEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF00695C)])
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
            // Input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _messageController,
                  textDirection: TextDirection.rtl,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Color(0xFF1A2332),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeChannelId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();
    HapticFeedback.lightImpact();

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final userMeta = client.auth.currentUser?.userMetadata;
      final senderName = userMeta?['full_name'] ?? 'مستخدم';

      await client.from('chat_messages').insert({
        'channel_id': _activeChannelId,
        'sender_id': userId,
        'sender_name': senderName,
        'content': text,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('فشل الإرسال',
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
            ListTile(
              leading: const Icon(Icons.copy_rounded,
                  color: Color(0xFF6B7280), size: 22),
              title: const Text('نسخ الرسالة',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: msg['content'] ?? ''));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isAnnouncement = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFF00897B), size: 24),
                  SizedBox(width: 10),
                  Text('إنشاء قناة جديدة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                    decoration: InputDecoration(
                      labelText: 'اسم القناة',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF00897B)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00897B), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      prefixIcon: const Icon(Icons.description_outlined,
                          color: Color(0xFF00897B)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00897B), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('قناة إعلانات (قراءة فقط)',
                          style: TextStyle(
                              fontFamily: 'Tajawal', fontSize: 13)),
                      secondary: const Icon(Icons.campaign_outlined,
                          color: Color(0xFFF59E0B), size: 22),
                      value: isAnnouncement,
                      activeColor: const Color(0xFF00897B),
                      onChanged: (v) =>
                          setDialogState(() => isAnnouncement = v),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    try {
                      final client = Supabase.instance.client;
                      await client.from('chat_channels').insert({
                        'name': nameController.text,
                        'description': descController.text.isNotEmpty
                            ? descController.text
                            : null,
                        'is_announcement': isAnnouncement,
                        'is_active': true,
                        'created_by': client.auth.currentUser?.id,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ref.invalidate(chatChannelsProvider);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('فشل: $e',
                                style: const TextStyle(
                                    fontFamily: 'Tajawal')),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('إنشاء',
                      style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showChannelMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.people_rounded,
                    color: Color(0xFF00897B), size: 24),
                SizedBox(width: 10),
                Text('أعضاء القناة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF00897B), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'جميع أعضاء الفريق يمكنهم الوصول لهذه القناة والمشاركة في المحادثات.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('إغلاق',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Color(0xFF6B7280))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pulse Dot ─────────────────────────────────────────────────────────────

class _ChatPulseDot extends StatefulWidget {
  const _ChatPulseDot();

  @override
  State<_ChatPulseDot> createState() => _ChatPulseDotState();
}

class _ChatPulseDotState extends State<_ChatPulseDot>
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
      builder: (context, _) {
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
  Widget build(BuildContext context) => builder(context, null);
}
