import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:epi_core/epi_core.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isConfigured = false;
  String? _currentUserId;
  String? _currentUserName;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _isConfigured = SupabaseConfig.isConfigured;
    if (_isConfigured) {
      _initUser();
      _loadMessages();
      // Poll every 5 seconds for new messages
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
    } else {
      _isLoading = false;
    }
  }

  void _initUser() {
    final client = Supabase.instance.client;
    _currentUserId = client.auth.currentUser?.id;
    _currentUserName = client.auth.currentUser?.userMetadata?['full_name'] ??
        client.auth.currentUser?.email?.split('@').first ??
        'مستخدم';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
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
          .limit(100);

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
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isConfigured) return;

    setState(() => _isSending = true);
    _messageController.clear();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, size: 22),
            SizedBox(width: 8),
            Text('الشات الداخلي', style: TextStyle(fontFamily: 'Cairo', fontSize: 18)),
          ],
        ),
        actions: [
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _loadMessages(),
              tooltip: 'تحديث',
            ),
        ],
      ),
      body: !_isConfigured
          ? _buildNotConfigured()
          : Column(
              children: [
                // Online indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: Colors.green.shade50,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'متصل — الرسائل تتحدث تلقائياً',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Messages list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => _loadMessages(),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isMe = msg['sender_id'] == _currentUserId;
                                  return _buildMessageBubble(msg, isMe);
                                },
                              ),
                            ),
                ),
                // Input bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            textDirection: TextDirection.rtl,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'اكتب رسالتك...',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              'الشات غير متاح',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يتطلب الاتصال بخادم Supabase\nللرسائل الفورية',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Colors.grey.shade600,
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.blue.shade300),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد رسائل بعد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ محادثة مع فريقك!\nستظهر الرسائل هنا',
              textAlign: TextAlign.center,
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

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final timeStr = DateFormat('HH:mm', 'ar').format(createdAt);
    final senderName = msg['sender_name'] ?? 'مستخدم';

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 4 : 16),
            bottomRight: Radius.circular(isMe ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Text(
                senderName,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: isMe ? Colors.white : Colors.black87,
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
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
