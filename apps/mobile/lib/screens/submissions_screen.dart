import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:epi_shared/epi_shared.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissions = ref.watch(submissionsProvider(SubmissionsFilter(status: _statusFilter)));

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
                    onTap: () => setState(() => _statusFilter = null),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(submissionsProvider(SubmissionsFilter(status: _statusFilter))),
              child: submissions.when(
                loading: () => const EpiLoading.shimmer(),
                error: (e, _) => EpiErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(submissionsProvider(SubmissionsFilter(status: _statusFilter))),
                ),
                data: (data) {
                  // Apply search filter
                  final filtered = _searchQuery.isEmpty
                      ? data
                      : data.where((sub) {
                          final formTitle = (sub['forms']?['title_ar'] ?? '').toString().toLowerCase();
                          final userName = (sub['profiles']?['full_name'] ?? '').toString().toLowerCase();
                          final status = (sub['status'] ?? '').toString().toLowerCase();
                          return formTitle.contains(_searchQuery) ||
                              userName.contains(_searchQuery) ||
                              status.contains(_searchQuery);
                        }).toList();

                  if (filtered.isEmpty) {
                    return EpiEmptyState(
                      icon: Icons.upload_file,
                      title: _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد إرساليات',
                      subtitle: _searchQuery.isNotEmpty ? 'جرّب كلمات بحث مختلفة' : 'لم يتم إرسال أي نماذج بعد',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final sub = filtered[index];
                      return _SubmissionTile(
                        title: sub['forms']?['title_ar'] ?? 'نموذج',
                        status: sub['status'] ?? 'draft',
                        date: sub['created_at'],
                        userName: sub['profiles']?['full_name'],
                        onTap: () => context.go('/submissions/${sub['id']}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
                    setState(() => _statusFilter = selected ? s : null);
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
}

class _SubmissionTile extends StatelessWidget {
  final String title;
  final String status;
  final String? date;
  final String? userName;
  final VoidCallback onTap;

  const _SubmissionTile({
    required this.title,
    required this.status,
    this.date,
    this.userName,
    required this.onTap,
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
              color: AppTheme.statusColor(status).withOpacity(0.1),
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
