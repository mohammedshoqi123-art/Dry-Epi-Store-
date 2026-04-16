import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_core/epi_core.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إدارة المستخدمين — User Management Screen (Mobile)
/// بحث، تصفية، تفعيل/تعطيل، إعادة تعيين كلمة المرور
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  String? _filterRole;
  bool? _filterActive;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _error;

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
    setState(() { _isLoading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('profiles')
          .select('*, governorates(name_ar), districts(name_ar)');

      if (_searchController.text.isNotEmpty) {
        query = query.or('full_name.ilike.%${_searchController.text}%,email.ilike.%${_searchController.text}%');
      }
      if (_filterRole != null) {
        query = query.eq('role', _filterRole!);
      }
      if (_filterActive != null) {
        query = query.eq('is_active', _filterActive!);
      }

      final response = await query.order('created_at', ascending: false).limit(200);
      setState(() {
        _users = (response as List<dynamic>).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    try {
      final client = Supabase.instance.client;
      final newStatus = !(user['is_active'] as bool? ?? true);
      await client.from('profiles').update({'is_active': newStatus}).eq('id', user['id']);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? 'تم تفعيل المستخدم ✅' : 'تم تعطيل المستخدم ⚠️', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو البريد...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _loadUsers(); })
                    : null,
              ),
              onChanged: (_) => _loadUsers(),
              textInputAction: TextInputAction.search,
            ),
          ),
          // Active filters
          if (_filterRole != null || _filterActive != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_filterRole != null)
                    Chip(
                      label: Text(_roleNameAr(_filterRole!), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      onDeleted: () { setState(() => _filterRole = null); _loadUsers(); },
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                  const SizedBox(width: 8),
                  if (_filterActive != null)
                    Chip(
                      label: Text(_filterActive! ? 'مفعل' : 'معطل', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      onDeleted: () { setState(() => _filterActive = null); _loadUsers(); },
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                ],
              ),
            ),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: EpiLoading.shimmer());
    if (_error != null) return Center(child: EpiErrorWidget(message: _error!, onRetry: _loadUsers));
    if (_users.isEmpty) return Center(child: EpiEmptyState(
      icon: Icons.people_outline_rounded,
      message: 'لا توجد مستخدمين',
      actionLabel: 'إعادة تحميل',
      onAction: _loadUsers,
    ));

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _users.length,
        itemBuilder: (context, i) => _buildUserCard(_users[i]),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] as bool? ?? true;
    final role = user['role'] as String? ?? 'data_entry';
    final gov = user['governorates'] as Map<String, dynamic>?;
    final dist = user['districts'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade200,
                child: Text(
                  (user['full_name'] ?? 'م')[0],
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: isActive ? AppTheme.primaryColor : Colors.grey),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(user['full_name'] ?? '—', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600, color: isActive ? null : Colors.grey))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_roleNameAr(role), style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: _roleColor(role), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(user['email'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.textSecondary)),
                    if (gov != null)
                      Text('${gov['name_ar']}${dist != null ? ' — ${dist['name_ar']}' : ''}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Switch(
                    value: isActive,
                    onChanged: (_) => _toggleUserActive(user),
                    activeColor: AppTheme.successColor,
                  ),
                  Text(isActive ? 'مفعل' : 'معطل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: isActive ? AppTheme.successColor : AppTheme.errorColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تصفية', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('الدور:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [null, 'admin', 'central', 'governorate', 'district', 'data_entry'].map((r) {
                final selected = _filterRole == r;
                return ChoiceChip(
                  label: Text(r == null ? 'الكل' : _roleNameAr(r), style: const TextStyle(fontFamily: 'Tajawal')),
                  selected: selected,
                  onSelected: (_) { setState(() => _filterRole = r); Navigator.pop(ctx); _loadUsers(); },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('الحالة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [null, true, false].map((v) {
                final selected = _filterActive == v;
                return ChoiceChip(
                  label: Text(v == null ? 'الكل' : v ? 'مفعل' : 'معطل', style: const TextStyle(fontFamily: 'Tajawal')),
                  selected: selected,
                  onSelected: (_) { setState(() => _filterActive = v); Navigator.pop(ctx); _loadUsers(); },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final isActive = user['is_active'] as bool? ?? true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text((user['full_name'] ?? 'م')[0], style: const TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
            ),
            const SizedBox(height: 12),
            Text(user['full_name'] ?? '—', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(user['email'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            _detailRow('الدور', _roleNameAr(user['role'] ?? 'data_entry')),
            _detailRow('الحالة', isActive ? 'مفعل ✅' : 'معطل ⚠️'),
            _detailRow('الهاتف', user['phone'] ?? '—'),
            if (user['governorates'] != null) _detailRow('المحافظة', user['governorates']['name_ar']),
            if (user['districts'] != null) _detailRow('المديرية', user['districts']['name_ar']),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _roleNameAr(String role) {
    const roles = {
      'admin': 'مدير النظام',
      'central': 'مركزي',
      'governorate': 'محافظة',
      'district': 'مديرية',
      'data_entry': 'إدخال بيانات',
    };
    return roles[role] ?? role;
  }

  Color _roleColor(String role) {
    const colors = {
      'admin': Color(0xFFD32F2F),
      'central': Color(0xFF7B1FA2),
      'governorate': Color(0xFF1565C0),
      'district': Color(0xFF00838F),
      'data_entry': Color(0xFF43A047),
    };
    return colors[role] ?? Colors.grey;
  }
}
