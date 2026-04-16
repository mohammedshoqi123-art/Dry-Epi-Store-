import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const SubmissionDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SubmissionDetailScreen> createState() =>
      _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState
    extends ConsumerState<SubmissionDetailScreen> {
  Map<String, dynamic>? _submission;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final data = await db.getSubmission(widget.id);
      setState(() {
        _submission = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل الإرسالية');
    }
  }

  /// Check if PDF can be generated (not for draft submissions)
  bool get _canGeneratePdf {
    final status = _submission?['status'] as String?;
    return status != null && status != 'draft';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: 'تفاصيل الإرسالية',
        actions: [
          if (_submission != null)
            PopupMenuButton<String>(
              onSelected: _handleAction,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'approve', child: Text('اعتماد')),
                const PopupMenuItem(value: 'reject', child: Text('رفض')),
                const PopupMenuItem(value: 'share', child: Text('مشاركة')),
                const PopupMenuItem(value: 'copy', child: Text('نسخ البيانات')),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const EpiLoading()
          : _submission == null
              ? const EpiErrorWidget(message: 'الإرسالية غير موجودة')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with PDF button
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // Status
                      _buildSection('الحالة', [
                        Row(
                          children: [
                            EpiStatusChip(
                                status: _submission!['status'] ?? 'draft'),
                            const Spacer(),
                            if (_submission!['submitted_at'] != null)
                              Text(
                                _formatDate(_submission!['submitted_at']),
                                style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Submitter info
                      _buildSection('المُرسل', [
                        _infoRow('الاسم',
                            _submission!['profiles']?['full_name'] ?? '-'),
                        _infoRow('البريد',
                            _submission!['profiles']?['email'] ?? '-'),
                      ]),
                      const SizedBox(height: 16),

                      // Location
                      if (_submission!['gps_lat'] != null)
                        _buildSection('الموقع', [
                          _infoRow('خط العرض', '${_submission!['gps_lat']}'),
                          _infoRow('خط الطول', '${_submission!['gps_lng']}'),
                        ]),
                      const SizedBox(height: 16),

                      // Form data
                      _buildSection('بيانات النموذج', _buildFormData()),
                      const SizedBox(height: 16),

                      // Review info
                      if (_submission!['reviewed_by'] != null)
                        _buildSection('المراجعة', [
                          _infoRow('راجع بواسطة',
                              _submission!['profiles']?['full_name'] ?? '-'),
                          _infoRow('تاريخ المراجعة',
                              _formatDate(_submission!['reviewed_at'])),
                          if (_submission!['review_notes'] != null)
                            _infoRow('ملاحظات', _submission!['review_notes']),
                        ]),

                      const SizedBox(height: 16),

                      // ═══ PDF Download Button (prominent) ═══
                      if (_canGeneratePdf) _buildPdfButton(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final status = _submission!['status'] ?? 'draft';
    final isSubmitted = status != 'draft';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSubmitted
              ? [AppTheme.primaryColor, AppTheme.primaryDark]
              : [Colors.grey.shade400, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isSubmitted ? AppTheme.primaryColor : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _submission!['forms']?['title_ar'] ?? 'نموذج',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.id.substring(0, 8)}...',
                  style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          EpiStatusChip(status: status),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PDF DOWNLOAD BUTTON — prominent, gradient, with loading state
  // ═══════════════════════════════════════════════════════════
  Widget _buildPdfButton() {
    return GestureDetector(
      onTap: _isGeneratingPdf ? null : _generatePDF,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: _isGeneratingPdf
              ? LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400])
              : const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFC62828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isGeneratingPdf
              ? []
              : [
                  const BoxShadow(
                    color: Color(0x4DE53935),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGeneratingPdf)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white, size: 24),
              ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGeneratingPdf
                      ? 'جارٍ إنشاء التقرير...'
                      : 'تحميل التقرير PDF',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (!_isGeneratingPdf)
                  Text(
                    'مشاركة أو حفظ كملف PDF',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
            if (!_isGeneratingPdf) ...[
              const Spacer(),
              const Icon(Icons.download_rounded, color: Colors.white, size: 22),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Divider(),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppTheme.textSecondary,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormData() {
    final data = _submission!['data'] as Map<String, dynamic>? ?? {};
    if (data.isEmpty)
      return [
        const Text('لا توجد بيانات',
            style:
                TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary))
      ];

    return data.entries.map((e) => _infoRow(e.key, '${e.value}')).toList();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    final d = DateTime.tryParse(dateStr.toString());
    if (d == null) return dateStr.toString();
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(String action) {
    switch (action) {
      case 'approve':
        _updateStatus('approved');
        break;
      case 'reject':
        _updateStatus('rejected');
        break;
      case 'share':
        _shareSubmission();
        break;
      case 'copy':
        _copyData();
        break;
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateSubmissionStatus(widget.id, status);
      _loadSubmission();
      if (mounted) context.showSuccess('تم تحديث الحالة');
    } catch (e) {
      if (mounted) context.showError('فشل التحديث');
    }
  }

  void _shareSubmission() {
    final data = _submission!['data'] as Map<String, dynamic>? ?? {};
    final formTitle = _submission!['forms']?['title_ar'] ?? 'نموذج';
    final status = _submission!['status'] ?? 'draft';
    final userName = _submission!['profiles']?['full_name'] ?? '-';
    final date = _formatDate(_submission!['created_at']);

    final text = StringBuffer();
    text.writeln('📋 $formTitle');
    text.writeln('━━━━━━━━━━━━━━━');
    text.writeln('الحالة: $status');
    text.writeln('المُرسل: $userName');
    text.writeln('التاريخ: $date');
    text.writeln('');
    if (data.isNotEmpty) {
      text.writeln('📊 البيانات:');
      data.forEach((key, value) {
        text.writeln('  • $key: $value');
      });
    }
    if (_submission!['gps_lat'] != null) {
      text.writeln('');
      text.writeln(
          '📍 الموقع: ${_submission!['gps_lat']}, ${_submission!['gps_lng']}');
    }
    text.writeln('');
    text.writeln('━━━━ EPI Supervisor ━━━━');

    SharePlus.instance.share(ShareParams(text: text.toString()));
  }

  void _copyData() {
    final data = _submission!['data'] as Map<String, dynamic>? ?? {};
    final text = data.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.showSuccess('تم نسخ البيانات');
  }

  // ═══════════════════════════════════════════════════════════
  // PDF GENERATION — with loading state and error handling
  // ═══════════════════════════════════════════════════════════
  Future<void> _generatePDF() async {
    if (_submission == null || _isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);
    HapticFeedback.mediumImpact();

    try {
      final form = _submission!['forms'] as Map<String, dynamic>? ?? {};
      final file = await FormReportGenerator.generate(
        form: form,
        submissions: [_submission!],
        period:
            'إرسال واحدة — ${(_submission!['created_at'] ?? '').toString().substring(0, 10)}',
      );

      if (!mounted) return;

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'تقرير استمارة EPI — ${form['title_ar'] ?? ''}',
      ));

      if (mounted) {
        context.showSuccess('تم إنشاء التقرير بنجاح ✅');
      }
    } catch (e) {
      if (mounted) {
        context.showError('فشل إنشاء التقرير: $e');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
}
