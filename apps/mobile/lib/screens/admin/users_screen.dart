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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            ),
          ),
          if (_roleFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(label: Text(_roleFilter!, style: const TextStyle(fontFamily: 'Tajawal'))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _roleFilter = null),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(databaseServiceProvider).getUsers(role: _roleFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EpiLoading.shimmer();
                }
                if (snapshot.hasError) {
                  return EpiErrorWidget(message: snapshot.error.toString());
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const EpiEmptyState(
                    icon: Icons.people,
                    title: 'لا يوجد مستخدمون',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserTile(
                      name: user['full_name'] ?? 'بدون اسم',
                      email: user['email'] ?? '',
                      role: user['role'] ?? 'data_entry',
                      isActive: user['is_active'] ?? true,
                      onTap: () => _showUserDetails(user),
                    );
                  },
                );
              },
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
              children: ['admin', 'central', 'governorate', 'district', 'data_entry'].map((role) {
                return ChoiceChip(
                  label: Text(_roleLabel(role), style: const TextStyle(fontFamily: 'Tajawal')),
                  selected: _roleFilter == role,
                  onSelected: (s) {
                    setState(() => _roleFilter = s ? role : null);
                    Navigator.pop(context);
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
    String selectedRole = 'data_entry';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
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
              builder: (context, setSheetState) => EpiDropdown<String>(
                label: 'الدور',
                value: selectedRole,
                items: ['admin', 'central', 'governorate', 'district', 'data_entry']
                    .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedRole = v!),
              ),
            ),
            const SizedBox(height: 20),
            EpiButton(
              text: 'إضافة',
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).callFunction('create-admin', {
                    'email': emailController.text,
                    'password': passwordController.text,
                    'full_name': nameController.text,
                    'role': selectedRole,
                  });
                  if (context.mounted) {
                    Navigator.pop(context); // ignore: use_build_context_synchronously
                    setState(() {});
                    context.showSuccess('تم إضافة المستخدم'); // ignore: use_build_context_synchronously
                  }
                } catch (e) {
                  if (context.mounted) context.showError('فشل: ${e.toString()}'); // ignore: use_build_context_synchronously
                }
              },
              width: double.infinity,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primarySurface,
              child: Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 12),
            Text(user['full_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            Text(user['email'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            EpiStatusChip(status: user['role'] ?? 'data_entry', label: _roleLabel(user['role'] ?? 'data_entry')),
            const SizedBox(height: 16),
            EpiButton(text: 'إغلاق', onPressed: () => Navigator.pop(context), width: double.infinity),
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
      case 'data_entry': return 'إدخال بيانات';
      default: return role;
    }
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final VoidCallback onTap;

  const _UserTile({
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EpiCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primarySurface,
            child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                Text(email, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          EpiStatusChip(status: role, small: true),
        ],
      ),
    );
  }
}
