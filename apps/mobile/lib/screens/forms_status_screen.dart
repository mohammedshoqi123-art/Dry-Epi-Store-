import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

/// Comprehensive forms status dashboard showing:
/// - Stats cards (drafts, submitted, synced, unsynced)
/// - Draft list with continue/edit actions
/// - Pending sync queue
/// - Recently submitted forms
class FormsStatusScreen extends ConsumerStatefulWidget {
  const FormsStatusScreen({super.key});

  @override
  ConsumerState<FormsStatusScreen> createState() => _FormsStatusScreenState();
}

class _FormsStatusScreenState extends ConsumerState<FormsStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: 'حالة الاستمارات',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(submissionsProvider(const SubmissionsFilter()));
              ref.invalidate(formsProvider);
              setState(() {}); // Force stats rebuild
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats summary cards
          _buildStatsSection(),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'المسودات'),
                Tab(text: 'قيد المزامنة'),
                Tab(text: 'المرسلة'),
                Tab(text: 'الكل'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DraftsTab(),
                _PendingSyncTab(),
                _SubmittedTab(),
                _AllTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'drafts': 0, 'pending': 0, 'submitted': 0, 'total': 0};
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'المسودات',
                  count: stats['drafts']!,
                  icon: Icons.edit_note,
                  color: AppTheme.warningColor,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFB8C00), Color(0xFFF57C00)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: 'قيد المزامنة',
                  count: stats['pending']!,
                  icon: Icons.sync,
                  color: AppTheme.infoColor,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: 'المرسلة',
                  count: stats['submitted']!,
                  icon: Icons.check_circle,
                  color: AppTheme.successColor,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  title: 'الكل',
                  count: stats['total']!,
                  icon: Icons.folder,
                  color: AppTheme.primaryColor,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// FIX: Use cached data only — no Supabase calls that can hang.
  /// Stats come from local offline storage, NOT from server.
  Future<Map<String, int>> _loadStats() async {
    int drafts = 0, pending = 0, total = 0;
    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Offline init timeout'),
      );
      pending = offline.pendingCount;

      // Count drafts from cached forms (no network call)
      final draftIds = offline.getDraftFormIds();
      drafts = draftIds.length;

      // Count cached submissions if available
      final cache = await ref.read(offlineDataCacheProvider.future).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Cache init timeout'),
      );
      final cachedSubs = cache.getCachedDataList('submissions');
      total = drafts + pending + (cachedSubs?.length ?? 0);
    } catch (e) {
      debugPrint('[FormsStatusScreen] Stats load error: $e');
    }

    return {
      'drafts': drafts,
      'pending': pending,
      'submitted': total > 0 ? total - drafts - pending : 0,
      'total': total,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DRAFTS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _DraftsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadDrafts(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EpiLoading.shimmer();
        }

        final drafts = snapshot.data ?? [];

        if (drafts.isEmpty) {
          return const EpiEmptyState(
            icon: Icons.edit_note,
            title: 'لا توجد مسودات',
            subtitle: 'المسودات المحفوظة ستظهر هنا تلقائياً',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            (context as Element).markNeedsBuild();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return _DraftTile(
                formId: draft['form_id'] as String,
                formTitle: draft['form_title'] as String? ?? 'نموذج',
                savedAt: draft['saved_at'] as String?,
                fieldCount: draft['field_count'] as int? ?? 0,
                onContinue: () => context.go('/forms/fill/${draft['form_id']}'),
                onDelete: () => _deleteDraft(context, ref, draft['form_id'] as String),
              );
            },
          ),
        );
      },
    );
  }

  /// FIX: Load drafts from local storage only — no Supabase calls.
  Future<List<Map<String, dynamic>>> _loadDrafts(WidgetRef ref) async {
    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('timeout'),
      );

      // Get draft IDs from local storage
      final draftIds = offline.getDraftFormIds();
      final drafts = <Map<String, dynamic>>[];

      // Try to get form titles from cache (no network call)
      final cache = await ref.read(offlineDataCacheProvider.future).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('timeout'),
      );
      final cachedForms = cache.getCachedDataList('forms') ?? [];

      for (final formId in draftIds) {
        final draft = offline.getDraft(formId);
        if (draft == null) continue;

        // Find title from cached forms
        String formTitle = 'نموذج';
        for (final f in cachedForms) {
          if (f['id'] == formId) {
            formTitle = f['title_ar'] ?? 'نموذج';
            break;
          }
        }

        drafts.add({
          'form_id': formId,
          'form_title': formTitle,
          'saved_at': draft['saved_at'],
          'field_count': (draft['data'] as Map?)?.length ?? 0,
          'data': draft['data'],
        });
      }

      // Sort by saved_at descending
      drafts.sort((a, b) {
        final aDate = DateTime.tryParse(a['saved_at'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['saved_at'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return drafts;
    } catch (e) {
      debugPrint('[DraftsTab] Load error: $e');
      return [];
    }
  }

  void _deleteDraft(BuildContext context, WidgetRef ref, String formId) async {
    final confirm = await context.showConfirmDialog(
      title: 'حذف المسودة',
      message: 'هل أنت متأكد من حذف هذه المسودة؟ لا يمكن التراجع.',
      confirmText: 'حذف',
      isDangerous: true,
    );
    if (confirm == true) {
      try {
        final offline = await ref.read(offlineManagerProvider.future);
        await offline.removeDraft(formId);
        if (context.mounted) {
          context.showSuccess('تم حذف المسودة');
          (context as Element).markNeedsBuild();
        }
      } catch (e) {
        if (context.mounted) context.showError('فشل الحذف');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PENDING SYNC TAB
// ═══════════════════════════════════════════════════════════════════════════

class _PendingSyncTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PendingSyncTab> createState() => _PendingSyncTabState();
}

class _PendingSyncTabState extends ConsumerState<_PendingSyncTab> {
  List<Map<String, dynamic>> _pendingItems = [];
  bool _isSyncing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // FIX: Use postFrameCallback to avoid reading providers before they're ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPending();
    });
  }

  Future<void> _loadPending() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final offline = await ref.read(offlineManagerProvider.future).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('timeout'),
      );
      final items = await offline.getPendingItems().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Map<String, dynamic>>[],
      );
      if (mounted) setState(() {
        _pendingItems = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PendingSyncTab] Load error: $e');
      if (mounted) setState(() {
        _pendingItems = [];
        _isLoading = false;
      });
    }
  }

  /// FIX: Better sync with proper error handling and timeout
  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final syncService = await ref.read(syncServiceProvider.future).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('انتهت مهلة تحميل خدمة المزامنة'),
      );

      final result = await syncService.sync().timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw Exception('انتهت مهلة المزامنة - تحقق من الاتصال'),
      );

      if (mounted) {
        final msg = 'تمت المزامنة: ${result.synced} ناجح، ${result.failed} فاشل';
        context.showSuccess(msg);
        await _loadPending();
      }
    } catch (e) {
      debugPrint('[PendingSyncTab] Sync error: $e');
      if (mounted) context.showError('فشلت المزامنة: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const EpiLoading.shimmer();
    }

    if (_pendingItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPending,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EpiEmptyState(
              icon: Icons.cloud_done,
              title: 'لا توجد عناصر معلقة',
              subtitle: 'جميع الاستمارات متزامنة مع الخادم',
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sync button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncNow,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                _isSyncing ? 'جاري المزامنة...' : 'مزامنة الكل (${_pendingItems.length})',
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.infoColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        // Items list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPending,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingItems.length,
              itemBuilder: (context, index) {
                final item = _pendingItems[index];
                return _PendingSyncTile(
                  offlineId: item['offline_id'] ?? 'unknown',
                  formId: item['form_id'] ?? '',
                  createdAt: item['created_at'],
                  retryCount: item['retry_count'] ?? 0,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUBMITTED TAB
// ═══════════════════════════════════════════════════════════════════════════

class _SubmittedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(submissionsProvider(const SubmissionsFilter()));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(submissionsProvider(const SubmissionsFilter())),
      child: submissions.when(
        loading: () => const EpiLoading.shimmer(),
        error: (e, _) => EpiErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(submissionsProvider(const SubmissionsFilter())),
        ),
        data: (data) {
          final submitted = data.where((s) =>
            s['status'] == 'submitted' ||
            s['status'] == 'reviewed' ||
            s['status'] == 'approved' ||
            s['status'] == 'rejected'
          ).toList();

          if (submitted.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EpiEmptyState(
                  icon: Icons.send,
                  title: 'لا توجد إرساليات',
                  subtitle: 'الاستمارات المُرسلة ستظهر هنا',
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submitted.length,
            itemBuilder: (context, index) {
              final sub = submitted[index];
              return _SubmittedTile(
                title: sub['forms']?['title_ar'] ?? 'نموذج',
                status: sub['status'] ?? 'submitted',
                date: sub['submitted_at'] ?? sub['created_at'],
                userName: sub['profiles']?['full_name'],
                isOffline: sub['is_offline'] == true,
                onTap: () => context.go('/submissions/${sub['id']}'),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALL TAB
// ═══════════════════════════════════════════════════════════════════════════

class _AllTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AllTab> createState() => _AllTabState();
}

class _AllTabState extends ConsumerState<_AllTab> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final submissions = ref.watch(submissionsProvider(SubmissionsFilter(status: _statusFilter)));

    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(label: 'الكل', value: null, current: _statusFilter, onSelected: _onFilter),
              const SizedBox(width: 8),
              _FilterChip(label: 'مسودة', value: 'draft', current: _statusFilter, onSelected: _onFilter),
              const SizedBox(width: 8),
              _FilterChip(label: 'مُرسل', value: 'submitted', current: _statusFilter, onSelected: _onFilter),
              const SizedBox(width: 8),
              _FilterChip(label: 'قيد المراجعة', value: 'reviewed', current: _statusFilter, onSelected: _onFilter),
              const SizedBox(width: 8),
              _FilterChip(label: 'معتمد', value: 'approved', current: _statusFilter, onSelected: _onFilter),
              const SizedBox(width: 8),
              _FilterChip(label: 'مرفوض', value: 'rejected', current: _statusFilter, onSelected: _onFilter),
            ],
          ),
        ),
        // List
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
                if (data.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      EpiEmptyState(
                        icon: Icons.folder_open,
                        title: 'لا توجد استمارات',
                        subtitle: 'لم يتم إنشاء أو إرسال أي استمارات بعد',
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final sub = data[index];
                    return _SubmittedTile(
                      title: sub['forms']?['title_ar'] ?? 'نموذج',
                      status: sub['status'] ?? 'draft',
                      date: sub['submitted_at'] ?? sub['created_at'],
                      userName: sub['profiles']?['full_name'],
                      isOffline: sub['is_offline'] == true,
                      onTap: () => context.go('/submissions/${sub['id']}'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _onFilter(String? value) {
    setState(() => _statusFilter = value);
    ref.invalidate(submissionsProvider(SubmissionsFilter(status: value)));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _DraftTile extends StatelessWidget {
  final String formId;
  final String formTitle;
  final String? savedAt;
  final int fieldCount;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  const _DraftTile({
    required this.formId,
    required this.formTitle,
    this.savedAt,
    required this.fieldCount,
    required this.onContinue,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFB8C00), Color(0xFFF57C00)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warningColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_note, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formTitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'مسودة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$fieldCount حقول',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                    if (savedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'آخر حفظ: ${_formatDate(savedAt!)}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: AppTheme.primaryColor),
                    onPressed: onContinue,
                    tooltip: 'متابعة التعبئة',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
                    onPressed: onDelete,
                    tooltip: 'حذف',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _PendingSyncTile extends StatelessWidget {
  final String offlineId;
  final String formId;
  final String? createdAt;
  final int retryCount;

  const _PendingSyncTile({
    required this.offlineId,
    required this.formId,
    this.createdAt,
    required this.retryCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = retryCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: hasErrors
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : AppTheme.infoColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasErrors
                      ? [const Color(0xFFE53935), const Color(0xFFC62828)]
                      : [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (hasErrors ? AppTheme.errorColor : AppTheme.infoColor).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                hasErrors ? Icons.sync_problem : Icons.cloud_upload,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'استمارة في الانتظار',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (hasErrors ? AppTheme.errorColor : AppTheme.infoColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasErrors ? 'فشل ($retryCount محاولات)' : 'في الانتظار',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: hasErrors ? AppTheme.errorColor : AppTheme.infoColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'تم الإنشاء: ${_formatDate(createdAt!)}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${offlineId.substring(0, 8)}...',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: hasErrors ? AppTheme.errorColor : AppTheme.infoColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (hasErrors ? AppTheme.errorColor : AppTheme.infoColor).withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _SubmittedTile extends StatelessWidget {
  final String title;
  final String status;
  final String? date;
  final String? userName;
  final bool isOffline;
  final VoidCallback onTap;

  const _SubmittedTile({
    required this.title,
    required this.status,
    this.date,
    this.userName,
    this.isOffline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.statusColor(status).withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: AppTheme.statusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isOffline)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi_off, size: 10, color: Colors.orange),
                                SizedBox(width: 3),
                                Text(
                                  'أوفلاين',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 9,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        EpiStatusChip(status: status, small: true),
                        if (userName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userName!,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(date!),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'submitted': return Icons.send;
      case 'reviewed': return Icons.rate_review;
      case 'draft': return Icons.edit_note;
      default: return Icons.description;
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month}/${d.year} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? current;
  final ValueChanged<String?> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.backgroundLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onSelected(value),
    );
  }
}
