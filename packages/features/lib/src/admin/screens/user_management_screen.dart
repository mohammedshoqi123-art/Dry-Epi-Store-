import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:csv/csv.dart';
import '../shared_providers.dart';

// ══════════════════════════════════════════════════════════════════════════════
// إدارة المستخدمين — User Management Screen
// بحث، تصفية، إنشاء، تعديل، تفعيل/تعطيل، حذف، تصدير CSV
// ══════════════════════════════════════════════════════════════════════════════

// ─── Providers ─────────────────────────────────────────────────────────────

final usersListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, UserFilters>(
        (ref, filters) async {
  final client = Supabase.instance.client;
  var query = client
      .from('profiles')
      .select('*, governorates(name_ar), districts(name_ar)');

  if (filters.search.isNotEmpty) {
    query = query.or(
        'full_name.ilike.%${filters.search}%,email.ilike.%${filters.search}%');
  }
  if (filters.role != null) {
    query = query.eq('role', filters.role!);
  }
  if (filters.governorateId != null) {
    query = query.eq('governorate_id', filters.governorateId!);
  }
  if (filters.isActive != null) {
    query = query.eq('is_active', filters.isActive!);
  }

  final response =
      await query.order('created_at', ascending: false).limit(200);
  return (response as List<dynamic>).cast<Map<String, dynamic>>();
});

// ─── Filters Model ─────────────────────────────────────────────────────────

class UserFilters {
  final String search;
  final String? role;
  final String? governorateId;
  final bool? isActive;

  const UserFilters({
    this.search = '',
    this.role,
    this.governorateId,
    this.isActive,
  });

  UserFilters copyWith({
    String? search,
    String? role,
    String? governorateId,
    bool? isActive,
  }) {
    return UserFilters(
      search: search ?? this.search,
      role: role ?? this.role,
      governorateId: governorateId ?? this.governorateId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserFilters &&
          search == other.search &&
          role == other.role &&
          governorateId == other.governorateId &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(search, role, governorateId, isActive);
}

// ─── Screen ────────────────────────────────────────────────────────────────

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();
  UserFilters _filters = const UserFilters();
  final Set<String> _selectedUserIds = {};
  int _currentPage = 0;
  static const int _pageSize = 15;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    setState(() {
      _filters = _filters.copyWith(search: value);
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: const Text('إدارة المستخدمين',
              style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _exportToCSV,
              tooltip: 'تصدير CSV',
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _showUserDialog(),
              tooltip: 'إضافة مستخدم',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilters(isWide),
            if (_selectedUserIds.isNotEmpty) _buildBulkActions(),
            Expanded(child: _buildUsersTable(isWide)),
          ],
        ),
      ),
    );
  }

  // ─── Filters Bar ──────────────────────────────────────────────────────

  Widget _buildFilters(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: isWide
          ? Row(children: _filterChildren())
          : Column(children: _filterChildren()),
    );
  }

  List<Widget> _filterChildren() {
    return [
      SizedBox(
        width: 280,
        child: TextField(
          controller: _searchController,
          onChanged: _applySearch,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'بحث بالاسم أو البريد...',
            prefixIcon:
                const Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _applySearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMedium,
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      const SizedBox(width: 12, height: 8),
      _buildRoleDropdown(),
      const SizedBox(width: 12, height: 8),
      _buildGovernorateDropdown(),
      const SizedBox(width: 12, height: 8),
      _buildStatusFilter(),
    ];
  }

  Widget _buildRoleDropdown() {
    const roles = {
      'admin': 'مدير النظام',
      'central': 'مركزي',
      'governorate': 'محافظة',
      'district': 'منطقة',
      'data_entry': 'إدخال بيانات',
    };

    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String?>(
        value: _filters.role,
        onChanged: (value) {
          setState(() {
            _filters = _filters.copyWith(role: value);
            _currentPage = 0;
          });
        },
        decoration: InputDecoration(
          hintText: 'الدور',
          filled: true,
          fillColor: AppTheme.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: AppTheme.radiusMedium,
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('كل الأدوار')),
          ...roles.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
        ],
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    return Consumer(
      builder: (context, ref, _) {
        final govsAsync = ref.watch(governoratesListProvider);
        return govsAsync.when(
          loading: () => const SizedBox(width: 180, height: 48),
          error: (_, __) => const SizedBox.shrink(),
          data: (govs) => SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: _filters.governorateId,
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(governorateId: value);
                  _currentPage = 0;
                });
              },
              decoration: InputDecoration(
                hintText: 'المحافظة',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: AppTheme.radiusMedium,
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('كل المحافظات')),
                ...govs.map((g) => DropdownMenuItem(
                    value: g['id'] as String,
                    child: Text(g['name_ar'] ?? ''))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusFilter() {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<bool?>(
        value: _filters.isActive,
        onChanged: (value) {
          setState(() {
            _filters = _filters.copyWith(isActive: value);
            _currentPage = 0;
          });
        },
        decoration: InputDecoration(
          hintText: 'الحالة',
          filled: true,
          fillColor: AppTheme.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: AppTheme.radiusMedium,
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('الكل')),
          DropdownMenuItem(value: true, child: Text('نشط')),
          DropdownMenuItem(value: false, child: Text('معطل')),
        ],
      ),
    );
  }

  // ─── Bulk Actions ─────────────────────────────────────────────────────

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primarySurface,
      child: Row(
        children: [
          Text(
            'تم تحديد ${_selectedUserIds.length} مستخدم',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _bulkToggleActive(true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('تفعيل'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _bulkToggleActive(false),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('تعطيل'),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _bulkDelete(),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('حذف'),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _selectedUserIds.clear()),
          ),
        ],
      ),
    );
  }

  // ─── Users Table / Cards ──────────────────────────────────────────────

  Widget _buildUsersTable(bool isWide) {
    return Consumer(
      builder: (context, ref, _) {
        final usersAsync = ref.watch(usersListProvider(_filters));

        return usersAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 8,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: AppTheme.radiusMedium,
                ),
              ),
            ),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('فشل تحميل المستخدمين',
                    style: TextStyle(fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(usersListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: AppTheme.textHint),
                    SizedBox(height: 16),
                    Text('لا يوجد مستخدمون',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }

            final paged = users
                .skip(_currentPage * _pageSize)
                .take(_pageSize)
                .toList();
            final totalPages = (users.length / _pageSize).ceil();

            return Column(
              children: [
                Expanded(
                  child: isWide
                      ? _buildDataTable(paged)
                      : _buildCardsList(paged),
                ),
                _buildPagination(totalPages, users.length),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> users) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(AppTheme.primarySurface),
        columns: [
          DataColumn(
            label: Checkbox(
              value: _selectedUserIds.length == users.length &&
                  users.isNotEmpty,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedUserIds
                        .addAll(users.map((u) => u['id'] as String));
                  } else {
                    _selectedUserIds.clear();
                  }
                });
              },
            ),
          ),
          const DataColumn(
              label: Text('الاسم',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('البريد',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('الدور',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('المحافظة',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('الحالة',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('آخر دخول',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          const DataColumn(
              label: Text('إجراءات',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
        ],
        rows: users.map((user) {
          final id = user['id'] as String;
          final isActive = user['is_active'] ?? true;
          final govName = user['governorates']?['name_ar'] ?? '—';
          final lastLogin = user['last_login'] != null
              ? DateFormat('d/M/yyyy')
                  .format(DateTime.parse(user['last_login']))
              : 'لم يسجل دخول';

          return DataRow(
            selected: _selectedUserIds.contains(id),
            onSelectChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedUserIds.add(id);
                } else {
                  _selectedUserIds.remove(id);
                }
              });
            },
            cells: [
              DataCell(Checkbox(
                value: _selectedUserIds.contains(id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedUserIds.add(id);
                    } else {
                      _selectedUserIds.remove(id);
                    }
                  });
                },
              )),
              DataCell(Text(user['full_name'] ?? '',
                  style: const TextStyle(fontFamily: 'Tajawal'))),
              DataCell(Text(user['email'] ?? '',
                  style:
                      const TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
              DataCell(_buildRoleChip(user['role'] ?? 'data_entry')),
              DataCell(Text(govName,
                  style: const TextStyle(fontFamily: 'Tajawal'))),
              DataCell(_buildStatusChip(isActive)),
              DataCell(Text(lastLogin,
                  style: const TextStyle(
                      fontFamily: 'Tajawal', fontSize: 12))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppTheme.infoColor),
                    onPressed: () => _showUserDialog(user: user),
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: Icon(
                      isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                      size: 18,
                      color: isActive
                          ? AppTheme.warningColor
                          : AppTheme.successColor,
                    ),
                    onPressed: () => _toggleUserActive(id, !isActive),
                    tooltip: isActive ? 'تعطيل' : 'تفعيل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.errorColor),
                    onPressed: () => _deleteUser(id),
                    tooltip: 'حذف',
                  ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardsList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final id = user['id'] as String;
        final isActive = user['is_active'] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMedium),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primarySurface,
              child: Text(
                (user['full_name'] ?? '؟')[0],
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor),
              ),
            ),
            title: Text(user['full_name'] ?? '',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'Tajawal', fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildRoleChip(user['role'] ?? 'data_entry'),
                    const SizedBox(width: 8),
                    _buildStatusChip(isActive),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _showUserDialog(user: user);
                    break;
                  case 'toggle':
                    _toggleUserActive(id, !isActive);
                    break;
                  case 'delete':
                    _deleteUser(id);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.infoColor),
                        SizedBox(width: 8),
                        Text('تعديل',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
                PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                            isActive
                                ? Icons.block_outlined
                                : Icons.check_circle_outline,
                            size: 18,
                            color: isActive
                                ? AppTheme.warningColor
                                : AppTheme.successColor),
                        const SizedBox(width: 8),
                        Text(isActive ? 'تعطيل' : 'تفعيل',
                            style:
                                const TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('حذف',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ],
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Chips ────────────────────────────────────────────────────────────

  Widget _buildRoleChip(String role) {
    const roleLabels = {
      'admin': 'مدير النظام',
      'central': 'مركزي',
      'governorate': 'محافظة',
      'district': 'منطقة',
      'data_entry': 'إدخال بيانات',
    };

    final color = role == 'admin'
        ? AppTheme.errorColor
        : role == 'central'
            ? AppTheme.secondaryColor
            : role == 'governorate'
                ? AppTheme.warningColor
                : role == 'district'
                    ? AppTheme.infoColor
                    : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        roleLabels[role] ?? role,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.successColor : AppTheme.errorColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'نشط' : 'معطل',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.successColor : AppTheme.errorColor,
        ),
      ),
    );
  }

  // ─── Pagination ───────────────────────────────────────────────────────

  Widget _buildPagination(int totalPages, int totalItems) {
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'إجمالي: $totalItems مستخدم',
          style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'إجمالي: $totalItems — صفحة ${_currentPage + 1} من $totalPages',
            style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: AppTheme.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              ...List.generate(totalPages.clamp(0, 5), (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _currentPage = i),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _currentPage == i
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Create / Edit User Dialog ────────────────────────────────────────

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final nameController =
        TextEditingController(text: user?['full_name'] ?? '');
    final emailController =
        TextEditingController(text: user?['email'] ?? '');
    final phoneController =
        TextEditingController(text: user?['phone'] ?? '');
    String selectedRole = user?['role'] ?? 'data_entry';
    String? selectedGovId = user?['governorate_id'];
    String? selectedDistId = user?['district_id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.radiusLarge),
              title: Text(
                isEdit ? 'تعديل المستخدم' : 'إضافة مستخدم جديد',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        onChanged: (v) =>
                            setDialogState(() => selectedRole = v!),
                        decoration: const InputDecoration(
                          labelText: 'الدور',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'admin',
                              child: Text('مدير النظام')),
                          DropdownMenuItem(
                              value: 'central',
                              child: Text('مركزي')),
                          DropdownMenuItem(
                              value: 'governorate',
                              child: Text('محافظة')),
                          DropdownMenuItem(
                              value: 'district',
                              child: Text('منطقة')),
                          DropdownMenuItem(
                              value: 'data_entry',
                              child: Text('إدخال بيانات')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final govsAsync =
                              ref.watch(governoratesListProvider);
                          return govsAsync.when(
                            loading: () => const CircularProgressIndicator(
                                strokeWidth: 2),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (govs) =>
                                DropdownButtonFormField<String?>(
                              value: selectedGovId,
                              onChanged: (v) => setDialogState(() {
                                selectedGovId = v;
                                selectedDistId = null;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'المحافظة',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('بدون')),
                                ...govs.map((g) => DropdownMenuItem(
                                    value: g['id'] as String,
                                    child: Text(g['name_ar'] ?? ''))),
                              ],
                            ),
                          );
                        },
                      ),
                      if (selectedGovId != null) ...[
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final distsAsync = ref
                                .watch(districtsListProvider(selectedGovId));
                            return distsAsync.when(
                              loading: () =>
                                  const CircularProgressIndicator(
                                      strokeWidth: 2),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (dists) =>
                                  DropdownButtonFormField<String?>(
                                value: selectedDistId,
                                onChanged: (v) => setDialogState(
                                    () => selectedDistId = v),
                                decoration: const InputDecoration(
                                  labelText: 'المنطقة / المديرية',
                                  prefixIcon:
                                      Icon(Icons.location_on_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('بدون')),
                                  ...dists.map((d) => DropdownMenuItem(
                                      value: d['id'] as String,
                                      child: Text(d['name_ar'] ?? ''))),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _saveUser(
                    ctx,
                    user?['id'],
                    nameController.text,
                    emailController.text,
                    phoneController.text,
                    selectedRole,
                    selectedGovId,
                    selectedDistId,
                  ),
                  icon: Icon(isEdit ? Icons.save : Icons.person_add,
                      size: 18),
                  label: Text(isEdit ? 'حفظ' : 'إضافة'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────

  Future<void> _saveUser(
    BuildContext ctx,
    String? userId,
    String name,
    String email,
    String phone,
    String role,
    String? govId,
    String? distId,
  ) async {
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الاسم والبريد مطلوبان',
              style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      if (userId != null) {
        await client.from('profiles').update({
          'full_name': name,
          'phone': phone.isNotEmpty ? phone : null,
          'role': role,
          'governorate_id': govId,
          'district_id': distId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } else {
        await client.functions.invoke('admin-actions', body: {
          'action': 'create_user',
          'email': email,
          'full_name': name,
          'phone': phone.isNotEmpty ? phone : null,
          'role': role,
          'governorate_id': govId,
          'district_id': distId,
        });
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userId != null
                  ? 'تم تحديث المستخدم بنجاح'
                  : 'تم إنشاء المستخدم بنجاح',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        ref.invalidate(usersListProvider);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserActive(String id, bool active) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active ? 'تم تفعيل المستخدم' : 'تم تعطيل المستخدم',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor:
                active ? AppTheme.successColor : AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل العملية: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirmed = await EpiDialog.show(
      context,
      title: 'حذف المستخدم',
      content:
          'هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      isDanger: true,
      icon: Icons.delete_forever,
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.functions
          .invoke('admin-actions', body: {
        'action': 'delete_user',
        'user_id': id,
      });
      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المستخدم',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحذف: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _bulkToggleActive(bool active) async {
    try {
      for (final id in _selectedUserIds) {
        await Supabase.instance.client.from('profiles').update({
          'is_active': active,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
      setState(() => _selectedUserIds.clear());
      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'تم تفعيل المستخدمين المحددين'
                  : 'تم تعطيل المستخدمين المحددين',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت العملية: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _bulkDelete() async {
    final confirmed = await EpiDialog.show(
      context,
      title: 'حذف ${_selectedUserIds.length} مستخدم',
      content: 'هل أنت متأكد من حذف المستخدمين المحددين؟',
      confirmText: 'حذف الكل',
      isDanger: true,
      icon: Icons.delete_forever,
    );

    if (confirmed != true) return;

    try {
      for (final id in _selectedUserIds) {
        await Supabase.instance.client.functions
            .invoke('admin-actions', body: {
          'action': 'delete_user',
          'user_id': id,
        });
      }
      setState(() => _selectedUserIds.clear());
      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المستخدمين',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحذف: $e',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('profiles')
          .select('*, governorates(name_ar), districts(name_ar)')
          .order('created_at', ascending: false);

      final users = response as List<dynamic>;

      final rows = <List<dynamic>>[
        ['الاسم', 'البريد', 'الهاتف', 'الدور', 'المحافظة', 'المنطقة', 'نشط', 'آخر دخول'],
        ...users.map((u) => [
              u['full_name'] ?? '',
              u['email'] ?? '',
              u['phone'] ?? '',
              u['role'] ?? '',
              u['governorates']?['name_ar'] ?? '',
              u['districts']?['name_ar'] ?? '',
              (u['is_active'] ?? true) ? 'نعم' : 'لا',
              u['last_login'] ?? '',
            ]),
      ];

      final csvData = const ListToCsvConverter().convert(rows);
      await Clipboard.setData(ClipboardData(text: csvData));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ بيانات CSV إلى الحافظة',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التصدير: $e',
                style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
