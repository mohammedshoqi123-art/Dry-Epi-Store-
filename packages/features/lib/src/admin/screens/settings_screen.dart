import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════
///  الإعدادات — Settings Screen
/// ═══════════════════════════════════════════════════════════════════

final settingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client.functions.invoke('manage-data', body: {
    'resource': 'settings',
    'action': 'list',
  });
  if (response.status != 200) throw Exception('فشل تحميل الإعدادات');
  return List<Map<String, dynamic>>.from(response.data['settings'] ?? []);
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  bool _hasChanges = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
      data: (settings) {
        _initControllers(settings);
        return _buildSettingsContent(settings);
      },
    );
  }

  void _initControllers(List<Map<String, dynamic>> settings) {
    for (final s in settings) {
      final key = s['key'] as String;
      final value = s['value'];
      if (!_controllers.containsKey(key)) {
        if (s['type'] == 'boolean') {
          _boolValues[key] = value == true || value == 'true';
        } else {
          _controllers[key] = TextEditingController(
            text: value is String ? value : value.toString(),
          );
        }
      }
    }
  }

  Widget _buildSettingsContent(List<Map<String, dynamic>> settings) {
    // Group by category
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final s in settings) {
      final cat = s['category'] as String? ?? 'general';
      categories.putIfAbsent(cat, () => []).add(s);
    }

    return Column(
      children: [
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFB8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFB8C00).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: Color(0xFFFB8C00)),
                const SizedBox(width: 12),
                const Text('لديك تغييرات غير محفوظة',
                    style: TextStyle(fontFamily: 'Tajawal')),
                const Spacer(),
                TextButton(
                    onPressed: () => _resetChanges(settings),
                    child: const Text('إلغاء')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () => _saveSettings(), child: const Text('حفظ')),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: categories.entries
                  .map((entry) => _buildCategoryCard(
                        _categoryLabel(entry.key),
                        _categoryIcon(entry.key),
                        entry.value,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
      String title, IconData icon, List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF00897B)),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => _buildSettingItem(item)),
        ],
      ),
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> item) {
    final key = item['key'] as String;
    final label = item['label_ar'] as String? ?? key;
    final type = item['type'] as String? ?? 'string';

    Widget trailing;
    switch (type) {
      case 'boolean':
        trailing = Switch(
          value: _boolValues[key] ?? false,
          activeColor: const Color(0xFF00897B),
          onChanged: (v) {
            setState(() {
              _boolValues[key] = v;
              _hasChanges = true;
            });
          },
        );
        break;
      case 'number':
        trailing = SizedBox(
          width: 100,
          child: TextField(
            controller: _controllers[key],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (_) => setState(() => _hasChanges = true),
          ),
        );
        break;
      case 'color':
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _parseColor(_controllers[key]?.text),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controllers[key],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
            ),
          ],
        );
        break;
      default:
        trailing = SizedBox(
          width: 250,
          child: TextField(
            controller: _controllers[key],
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (_) => setState(() => _hasChanges = true),
          ),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 14, fontFamily: 'Tajawal')),
                Text(key,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      final clean = hex.replaceAll('#', '').replaceAll('"', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'branding':
        return 'العلامة التجارية';
      case 'security':
        return 'الأمان';
      case 'offline':
        return 'وضع عدم الاتصال';
      case 'sync':
        return 'المزامنة';
      case 'ai':
        return 'الذكاء الاصطناعي';
      case 'notifications':
        return 'الإشعارات';
      case 'uploads':
        return 'الرفع';
      case 'workflow':
        return 'سير العمل';
      case 'general':
        return 'عام';
      default:
        return cat;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'branding':
        return Icons.palette_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'offline':
        return Icons.cloud_off_rounded;
      case 'sync':
        return Icons.sync_rounded;
      case 'ai':
        return Icons.smart_toy_rounded;
      case 'notifications':
        return Icons.notifications_rounded;
      case 'uploads':
        return Icons.upload_rounded;
      case 'workflow':
        return Icons.work_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  void _resetChanges(List<Map<String, dynamic>> settings) {
    _controllers.clear();
    _boolValues.clear();
    setState(() => _hasChanges = false);
  }

  void _saveSettings() async {
    try {
      final updates = <Map<String, dynamic>>[];
      for (final entry in _controllers.entries) {
        updates.add({'key': entry.key, 'value': '"${entry.value.text}"'});
      }
      for (final entry in _boolValues.entries) {
        updates.add({'key': entry.key, 'value': entry.value});
      }

      await Supabase.instance.client.functions.invoke('manage-data', body: {
        'resource': 'settings',
        'action': 'update',
        'settings': updates,
      });

      setState(() => _hasChanges = false);
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
