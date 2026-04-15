import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:epi_shared/epi_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
// الدردشة الداخلية — Internal Chat
// مراسلة فورية بين فريق العمل + إدارة من لوحة المدير
// ══════════════════════════════════════════════════════════════════════════════

/// مزود الرسائل — يستمع realtime
final chatMessagesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

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

/// مزود عدد الرسائل غير المقروءة
final chatUnreadProvider = FutureProvider<int>((ref) async {
  final client = Supabase.instance.client;
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 0;
    final response = await client
        .from('chat_messages')
        .select('id')
        .neq('sender_id', userId)
        .gt('created_at',
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String());
    // Simplified — in production you'd track read status per user
    return (response as List).length;
  } catch (_) {
    return 0;
  }
});

// ─── Screen ────────────────────────────────────────────────────────────────

class InternalChatScreen extends ConsumerStatefulWidget {
  /// إذا null → عرض قائمة القنوات، وإلا عرض محادثة القناة
  final String? channelId;
  final String? channelName;

  const InternalChatScreen({super.key, this.channelId, this.channelName});

  @override
  ConsumerState<InternalChatScreen> createState() =>
      _InternalChatScreenState();
}

class _InternalChatScreenState extends ConsumerState<InternalChatScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: Text(
            _activeChannelName ?? 'الدردشة الداخلية',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            if (_activeChannelId != null)
              IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: () => _showChannelMembers(),
                tooltip: 'الأعضاء',
              ),
          ],
        ),
        body: _activeChannelId == null
            ? _buildChannelsList()
            : _buildChatView(),
      ),
    );
  }

  // ─── قائمة القنوات ──────────────────────────────────────────────────

  Widget _buildChannelsList() {
    return Column(
      children: [
        // زر إنشاء قناة
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateChannelDialog(),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('إنشاء قناة جديدة',
                  style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ),
        ),
        // القنوات
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final channelsAsync = ref.watch(chatChannelsProvider);

              return channelsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)),
                error: (_, __) => const Center(
                    child: Text('فشل تحميل القنوات',
                        style: TextStyle(fontFamily: 'Tajawal'))),
                data: (channels) {
                  if (channels.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: AppTheme.textHint),
                          SizedBox(height: 16),
                          Text('لا توجد قنوات',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 16,
                                  color: AppTheme.textSecondary)),
                          SizedBox(height: 8),
                          Text('أنشئ قناة لبدء المحادثة',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  color: AppTheme.textHint)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusMedium),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              ch['is_announcement'] == true
                                  ? Icons.campaign_outlined
                                  : Icons.chat_bubble_outline,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            ch['name'] ?? 'قناة',
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            ch['description'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Tajawal', fontSize: 12),
                          ),
                          trailing: const Icon(
                              Icons.arrow_back_ios_new, size: 16),
                          onTap: () {
                            setState(() {
                              _activeChannelId = ch['id'];
                              _activeChannelName = ch['name'];
                            });
                          },
                        ),
                      );
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

  // ─── عرض المحادثة ───────────────────────────────────────────────────

  Widget _buildChatView() {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id ?? '';

    return Column(
      children: [
        // الرسائل
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              // نستخدم realtime stream على الرسائل
              final messagesStream = client
                  .from('chat_messages')
                  .stream(primaryKey: ['id'])
                  .eq('channel_id', _activeChannelId!)
                  .order('created_at', ascending: true)
                  .limit(200);

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor));
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48, color: AppTheme.textHint),
                          SizedBox(height: 12),
                          Text('ابدأ المحادثة!',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }

                  // Auto-scroll للأسفل
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == currentUserId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              );
            },
          ),
        ),
        // حقل الإدخال
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ??
        DateTime.now();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final senderName = msg['sender_name'] ?? 'مستخدم';

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryColor
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 4 : 16),
            bottomRight: Radius.circular(isMe ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Text(
                senderName,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: isMe ? Colors.white : AppTheme.textPrimary,
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
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.textHint,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg['is_read'] == true
                        ? Icons.done_all
                        : Icons.done,
                    size: 14,
                    color: msg['is_read'] == true
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // زر الإرسال
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            // حقل النص
            Expanded(
              child: TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── الإجراءات ──────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeChannelId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
                  borderRadius: AppTheme.radiusLarge),
              title: const Text('إنشاء قناة جديدة',
                  style: TextStyle(fontFamily: 'Cairo')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم القناة',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('قناة إعلانات (قراءة فقط)',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                    value: isAnnouncement,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) =>
                        setDialogState(() => isAnnouncement = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
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
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('إنشاء'),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أعضاء القناة',
                  style: AppTheme.headingM.copyWith(fontSize: 17)),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'جميع أعضاء الفريق يمكنهم الوصول لهذه القناة.',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  label: const Text('إغلاق',
                      style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
