import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../../providers/app_providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String? _roleFilter;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _cachedUsers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await ref.read(databaseServiceProvider).getUsers(role: _roleFilter);
      setState(() {
        _cachedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showError('فشل تحميل المستخدمين');
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _cachedUsers ?? [];

    // Apply search filter
    final query = _searchController.text.toLowerCase();
    final filteredUsers = query.isEmpty
        ? users
        : users.where((u) {
            final name = (u['full_name'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();

    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.users,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserSheet,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: EpiSearchBar(
              controller: _searchController,
              hint: 'بحث عن مستخدم...',
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_roleFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(label: Text(_roleLabel(_roleFilter!), style: const TextStyle(fontFamily: 'Tajawal'))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _roleFilter = null);
                      _loadUsers();
                    },
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const EpiLoading.shimmer()
                : filteredUsers.isEmpty
                    ? const EpiEmptyState(icon: Icons.people, title: 'لا يوجد مستخدمون')
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return _UserTile(
                              name: user['full_name'] ?? 'بدون اسم',
                              email: user['email'] ?? '',
                              role: user['role'] ?? 'teamLead',
                              isActive: user['is_active'] ?? true,
                              governorate: user['governorates']?['name_ar'],
                              onTap: () => _showUserDetails(user),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تصفية حسب الدور',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['admin', 'central', 'governorate', 'district', 'teamLead'].map((role) {
                return ChoiceChip(
                  label: Text(_roleLabel(role), style: const TextStyle(fontFamily: 'Tajawal')),
                  selected: _roleFilter == role,
                  onSelected: (s) {
                    setState(() => _roleFilter = s ? role : null);
                    Navigator.pop(context);
                    _loadUsers();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserSheet() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'teamLead';
    String? selectedGovernorateId;
    String? selectedDistrictId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إضافة مستخدم',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              EpiTextField(label: 'الاسم الكامل', controller: nameController, prefixIcon: Icons.person),
              const SizedBox(height: 12),
              EpiTextField(label: 'البريد', controller: emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email),
              const SizedBox(height: 12),
              EpiTextField(label: 'كلمة المرور', controller: passwordController, obscureText: true, prefixIcon: Icons.lock),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setSheetState) => Column(
                  children: [
                    EpiDropdown<String>(
                      label: 'الدور',
                      value: selectedRole,
                      items: ['admin', 'central', 'governorate', 'district', 'teamLead']
                          .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedRole = v!),
                    ),
                    const SizedBox(height: 12),
                    // Governorate dropdown (for governorate/district/data_entry roles)
                    if (selectedRole != 'admin' && selectedRole != 'central')
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: ref.read(databaseServiceProvider).getGovernorates(),
                        builder: (context, snapshot) {
                          final governorates = snapshot.data ?? [];
                          return EpiDropdown<String>(
                            label: 'المحافظة',
                            value: selectedGovernorateId,
                            items: governorates
                                .map((g) => DropdownMenuItem(
                                      value: g['id'] as String,
                                      child: Text(g['name_ar'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => setSheetState(() {
                              selectedGovernorateId = v;
                              selectedDistrictId = null;
                            }),
                          );
                        },
                      ),
                    if (selectedGovernorateId != null && (selectedRole == 'district' || selectedRole == 'teamLead'))
                      const SizedBox(height: 12),
                    // District dropdown
                    if (selectedGovernorateId != null && (selectedRole == 'district' || selectedRole == 'teamLead'))
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: ref.read(databaseServiceProvider).getDistricts(governorateId: selectedGovernorateId),
                        builder: (context, snapshot) {
                          final districts = snapshot.data ?? [];
                          return EpiDropdown<String>(
                            label: 'المديرية',
                            value: selectedDistrictId,
                            items: districts
                                .map((d) => DropdownMenuItem(
                                      value: d['id'] as String,
                                      child: Text(d['name_ar'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => setSheetState(() => selectedDistrictId = v),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              EpiButton(
                text: 'إضافة',
                onPressed: () async {
                  if (emailController.text.isEmpty || passwordController.text.isEmpty || nameController.text.isEmpty) {
                    context.showError('جميع الحقول مطلوبة');
                    return;
                  }
                  try {
                    await ref.read(apiClientProvider).callFunction('create-admin', {
                      'email': emailController.text.trim(),
                      'password': passwordController.text,
                      'full_name': nameController.text.trim(),
                      'role': selectedRole,
                      'governorate_id': selectedGovernorateId,
                      'district_id': selectedDistrictId,
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadUsers();
                    if (ctx.mounted) ctx.showSuccess('تم إضافة المستخدم بنجاح');
                  } catch (e) {
                    if (ctx.mounted) ctx.showError('فشل: ${e.toString()}');
                  }
                },
                width: double.infinity,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final userId = user['id'] as String?;
    final currentRole = user['role'] as String? ?? 'teamLead';
    final isActive = user['is_active'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: isActive ? AppTheme.primarySurface : Colors.grey.shade200,
              child: Icon(Icons.person, size: 40, color: isActive ? AppTheme.primaryColor : Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(user['full_name'] ?? '',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            Text(user['email'] ?? '',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EpiStatusChip(status: currentRole, label: _roleLabel(currentRole)),
                const SizedBox(width: 8),
                if (!isActive)
                  const EpiStatusChip(status: 'inactive', label: 'معطّل'),
              ],
            ),
            if (user['governorates']?['name_ar'] != null) ...[
              const SizedBox(height: 8),
              Text('المحافظة: ${user['governorates']['name_ar']}',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
            ],
            if (user['districts']?['name_ar'] != null)
              Text('المديرية: ${user['districts']['name_ar']}',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
            const SizedBox(height: 20),

            // Actions
            _buildActionButton(
              icon: Icons.edit,
              label: 'تعديل الدور والمنطقة',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context);
                _showEditUserSheet(user);
              },
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: isActive ? Icons.block : Icons.check_circle,
              label: isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
              color: isActive ? AppTheme.warningColor : AppTheme.successColor,
              onTap: () {
                Navigator.pop(context);
                _toggleUserActive(userId!, !isActive);
              },
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'حذف المستخدم',
              color: AppTheme.errorColor,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteUser(userId!, user['full_name'] ?? '');
              },
            ),
            const SizedBox(height: 12),
            EpiButton(text: 'إغلاق', onPressed: () => Navigator.pop(context), width: double.infinity),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontFamily: 'Tajawal', color: color)),
          ],
        ),
      ),
    );
  }

  void _showEditUserSheet(Map<String, dynamic> user) {
    String selectedRole = user['role'] ?? 'teamLead';
    String? selectedGovernorateId = user['governorate_id'];
    String? selectedDistrictId = user['district_id'];
    final userId = user['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعديل المستخدم',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              EpiDropdown<String>(
                label: 'الدور',
                value: selectedRole,
                items: ['admin', 'central', 'governorate', 'district', 'teamLead']
                    .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedRole = v!),
              ),
              const SizedBox(height: 12),
              if (selectedRole != 'admin' && selectedRole != 'central')
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref.read(databaseServiceProvider).getGovernorates(),
                  builder: (context, snapshot) {
                    final governorates = snapshot.data ?? [];
                    return EpiDropdown<String>(
                      label: 'المحافظة',
                      value: selectedGovernorateId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون')),
                        ...governorates.map((g) => DropdownMenuItem(
                              value: g['id'] as String,
                              child: Text(g['name_ar'] as String),
                            )),
                      ],
                      onChanged: (v) => setSheetState(() {
                        selectedGovernorateId = v;
                        selectedDistrictId = null;
                      }),
                    );
                  },
                ),
              if (selectedGovernorateId != null && (selectedRole == 'district' || selectedRole == 'teamLead')) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref.read(databaseServiceProvider).getDistricts(governorateId: selectedGovernorateId),
                  builder: (context, snapshot) {
                    final districts = snapshot.data ?? [];
                    return EpiDropdown<String>(
                      label: 'المديرية',
                      value: selectedDistrictId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون')),
                        ...districts.map((d) => DropdownMenuItem(
                              value: d['id'] as String,
                              child: Text(d['name_ar'] as String),
                            )),
                      ],
                      onChanged: (v) => setSheetState(() => selectedDistrictId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              EpiButton(
                text: 'حفظ التعديلات',
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).callFunction('admin-actions', {
                      'action': 'update_role',
                      'user_id': userId,
                      'role': selectedRole,
                      'governorate_id': selectedGovernorateId,
                      'district_id': selectedDistrictId,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadUsers();
                      context.showSuccess('تم تحديث المستخدم');
                    }
                  } catch (e) {
                    if (context.mounted) context.showError('فشل: ${e.toString()}');
                  }
                },
                width: double.infinity,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserActive(String userId, bool makeActive) async {
    final confirmed = await context.showConfirmDialog(
      title: makeActive ? 'تفعيل الحساب' : 'تعطيل الحساب',
      message: makeActive
          ? 'هل تريد تفعيل هذا الحساب؟'
          : 'هل تريد تعطيل هذا الحساب؟ لن يتمكن المستخدم من تسجيل الدخول.',
      confirmText: makeActive ? 'تفعيل' : 'تعطيل',
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).callFunction('admin-actions', {
        'action': 'toggle_active',
        'user_id': userId,
        'is_active': makeActive,
      });
      _loadUsers();
      if (mounted) context.showSuccess(makeActive ? 'تم تفعيل الحساب' : 'تم تعطيل الحساب');
    } catch (e) {
      if (mounted) context.showError('فشل: ${e.toString()}');
    }
  }

  Future<void> _confirmDeleteUser(String userId, String userName) async {
    final confirmed = await context.showConfirmDialog(
      title: 'حذف المستخدم',
      message: 'هل أنت متأكد من حذف "$userName"؟ هذا الإجراء لا يمكن التراجع عنه.',
      confirmText: 'حذف',
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).callFunction('admin-actions', {
        'action': 'delete_user',
        'user_id': userId,
      });
      _loadUsers();
      if (mounted) context.showSuccess('تم حذف المستخدم');
    } catch (e) {
      if (mounted) context.showError('فشل: ${e.toString()}');
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'مدير النظام';
      case 'central': return 'مركزي';
      case 'governorate': return 'محافظة';
      case 'district': return 'قضاء';
      case 'teamLead': return 'إدخال بيانات';
      default: return role;
    }
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String? governorate;
  final VoidCallback onTap;

  const _UserTile({
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.governorate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: EpiCard(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? AppTheme.primarySurface : Colors.grey.shade200,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: TextStyle(
                  color: isActive ? AppTheme.primaryColor : Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                      ),
                      if (!isActive)
                        const Icon(Icons.block, size: 16, color: AppTheme.warningColor),
                    ],
                  ),
                  Text(email, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
                  if (governorate != null)
                    Text(governorate!, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EpiStatusChip(status: role, label: _roleLabel(role), small: true),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'central': return 'مركزي';
      case 'governorate': return 'محافظة';
      case 'district': return 'قضاء';
      case 'teamLead': return 'إدخال';
      default: return role;
    }
  }
}
