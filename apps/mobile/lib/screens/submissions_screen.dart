import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class SubmissionsScreen extends ConsumerStatefulWidget {
  const SubmissionsScreen({super.key});

  @override
  ConsumerState<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends ConsumerState<SubmissionsScreen> {
  String? _statusFilter;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Pagination state
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Detect when user scrolls near the bottom → load more
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Load first batch
  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });

    await _fetchPage();
  }

  /// Load next page (triggered by scroll)
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    await _fetchPage();
  }

  /// Fetch a single page from provider/cache
  Future<void> _fetchPage() async {
    setState(() => _isLoadingMore = true);

    try {
      final campaign = ref.read(campaignProvider);
      final filter = SubmissionsFilter(
        status: _statusFilter,
        campaignType: campaign.value,
        limit: _pageSize,
        offset: _offset,
      );

      final data = await ref.read(submissionsProvider(filter).future);

      setState(() {
        _items.addAll(data);
        _offset += data.length;
        _hasMore = data.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// Pull-to-refresh: clear cache and reload
  Future<void> _refresh() async {
    if (!ConnectivityUtils.isOnline) return;
    final campaign = ref.read(campaignProvider);
    final filter = SubmissionsFilter(status: _statusFilter, campaignType: campaign.value);
    await ref.read(forceRefreshProvider)(filter.cacheKey);
    ref.invalidate(submissionsProvider(filter));
    await _loadInitial();
  }

  /// Filter changed — reload from scratch
  void _onFilterChanged(String? status) {
    setState(() => _statusFilter = status);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    // Apply local search filter on loaded items
    final filtered = _searchQuery.isEmpty
        ? _items
        : _items.where((sub) {
            final formTitle = (sub['forms']?['title_ar'] ?? '').toString().toLowerCase();
            final userName = (sub['profiles']?['full_name'] ?? '').toString().toLowerCase();
            final status = (sub['status'] ?? '').toString().toLowerCase();
            return formTitle.contains(_searchQuery) ||
                userName.contains(_searchQuery) ||
                status.contains(_searchQuery);
          }).toList();

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.submissions,
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: EpiSearchBar(
              controller: _searchController,
              hint: 'بحث في الإرساليات...',
              onChanged: (query) => setState(() => _searchQuery = query.toLowerCase()),
            ),
          ),
          if (_statusFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  EpiStatusChip(status: _statusFilter!),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _onFilterChanged(null),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(filtered),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> filtered) {
    // Initial loading
    if (_isLoading) {
      return const EpiLoading.shimmer();
    }

    // Error state
    if (_error != null && _items.isEmpty) {
      return EpiErrorWidget(
        message: _error!,
        onRetry: _loadInitial,
      );
    }

    // Empty state
    if (filtered.isEmpty && !_isLoadingMore) {
      return EpiEmptyState(
        icon: Icons.upload_file,
        title: _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد إرساليات',
        subtitle: _searchQuery.isNotEmpty ? 'جرّب كلمات بحث مختلفة' : 'لم يتم إرسال أي نماذج بعد',
      );
    }

    // List with lazy loading
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + (_hasMore || _isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Bottom loading indicator
        if (index >= filtered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)
                  : const SizedBox.shrink(),
            ),
          );
        }

        final sub = filtered[index];
        final status = sub['status'] ?? 'draft';
        final canPdf = status != 'draft';

        return _SubmissionTile(
          title: sub['forms']?['title_ar'] ?? 'نموذج',
          status: status,
          date: sub['created_at'],
          userName: sub['profiles']?['full_name'],
          onTap: () => context.go('/submissions/${sub['id']}'),
          onPdf: canPdf ? () => _quickGeneratePdf(sub) : null,
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تصفية حسب الحالة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['draft', 'submitted', 'reviewed', 'approved', 'rejected'].map((s) {
                return ChoiceChip(
                  label: EpiStatusChip(status: s, small: true),
                  selected: _statusFilter == s,
                  onSelected: (selected) {
                    _onFilterChanged(selected ? s : null);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Quick PDF generation from the list tile
  Future<void> _quickGeneratePdf(Map<String, dynamic> sub) async {
    HapticFeedback.lightImpact();

    try {
      final form = sub['forms'] as Map<String, dynamic>? ?? {};
      final file = await FormReportGenerator.generate(
        form: form,
        submissions: [sub],
        period: 'إرسال واحدة — ${(sub['created_at'] ?? '').toString().substring(0, 10)}',
      );

      if (!mounted) return;

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'تقرير استمارة EPI — ${form['title_ar'] ?? ''}',
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء التقرير ✅', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء التقرير: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class _SubmissionTile extends StatelessWidget {
  final String title;
  final String status;
  final String? date;
  final String? userName;
  final VoidCallback onTap;
  final VoidCallback? onPdf;

  const _SubmissionTile({
    required this.title,
    required this.status,
    this.date,
    this.userName,
    required this.onTap,
    this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    return EpiCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description, color: AppTheme.statusColor(status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (userName != null)
                  Text(userName!,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
                if (date != null)
                  Text(_formatDate(date!),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
          // ═══ PDF Button (only for non-draft submissions) ═══
          if (onPdf != null)
            GestureDetector(
              onTap: onPdf,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFE53935),
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 4),
          EpiStatusChip(status: status, small: true),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month}/${d.year}';
  }
}
