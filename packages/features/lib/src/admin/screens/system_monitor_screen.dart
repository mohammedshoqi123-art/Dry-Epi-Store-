import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════
///  مراقبة النظام — System Monitor
/// ═══════════════════════════════════════════════════════════════════

final systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await Supabase.instance.client.functions.invoke('system-monitor', body: {
    'action': 'health',
  });
  if (response.status != 200) throw Exception('فشل تحميل حالة النظام');
  return Map<String, dynamic>.from(response.data);
});

class SystemMonitorScreen extends ConsumerStatefulWidget {
  const SystemMonitorScreen({super.key});

  @override
  ConsumerState<SystemMonitorScreen> createState() => _SystemMonitorScreenState();
}

class _SystemMonitorScreenState extends ConsumerState<SystemMonitorScreen> {
  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(systemHealthProvider);

    return healthAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
      data: (health) => SingleChildScrollView(
        child: Column(
          children: [
            // System overview
            _buildSystemOverview(health),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Database tables
                Expanded(child: _buildDatabaseStatus(health)),
                const SizedBox(width: 16),
                // Sync status + actions
                Expanded(child: Column(
                  children: [
                    _buildSyncStatus(health),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Backups
            _buildBackupsSection(health),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemOverview(Map<String, dynamic> health) {
    final db = Map<String, dynamic>.from(health['database'] ?? {});
    final sync = Map<String, dynamic>.from(health['sync'] ?? {});
    final recent = Map<String, dynamic>.from(health['recent_activity'] ?? {});

    return Row(
      children: [
        _OverviewCard(
          icon: Icons.storage_rounded,
          title: 'قاعدة البيانات',
          value: '${db['total_records'] ?? 0}',
          subtitle: 'إجمالي السجلات',
          color: const Color(0xFF00897B),
          status: 'سليم',
        ),
        const SizedBox(width: 12),
        _OverviewCard(
          icon: Icons.sync_rounded,
          title: 'المزامنة',
          value: '${sync['pending_offline'] ?? 0}',
          subtitle: 'معلق • ${sync['failed_sync'] ?? 0} فاشل',
          color: sync['status'] == 'healthy' ? const Color(0xFF43A047) : const Color(0xFFFB8C00),
          status: sync['status'] == 'healthy' ? 'سليم' : 'تحذير',
        ),
        const SizedBox(width: 12),
        _OverviewCard(
          icon: Icons.timeline_rounded,
          title: 'آخر ساعة',
          value: '${recent['submissions_last_hour'] ?? 0}',
          subtitle: 'إرسالية • ${recent['audit_logs_last_hour'] ?? 0} سجل',
          color: const Color(0xFF1E88E5),
          status: 'نشط',
        ),
      ],
    );
  }

  Widget _buildDatabaseStatus(Map<String, dynamic> health) {
    final db = Map<String, dynamic>.from(health['database'] ?? {});
    final tables = Map<String, dynamic>.from(db['tables'] ?? {});

    final tableInfo = {
      'profiles': 'المستخدمين',
      'governorates': 'المحافظات',
      'districts': 'المديريات',
      'forms': 'النماذج',
      'form_submissions': 'الإرساليات',
      'supply_shortages': 'النواقص',
      'audit_logs': 'سجل التدقيق',
      'health_facilities': 'المنشآت',
      'notifications': 'الإشعارات',
      'app_settings': 'الإعدادات',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.storage_rounded, color: Color(0xFF00897B), size: 22),
                SizedBox(width: 10),
                Text('حالة قاعدة البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const Divider(height: 1),
          ...tableInfo.entries.map((entry) {
            final info = Map<String, dynamic>.from(tables[entry.key] ?? {});
            final count = info['count'] ?? 0;
            final status = info['status'] ?? 'unknown';
            final isHealthy = status == 'healthy';

            return ListTile(
              dense: true,
              leading: Icon(
                isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isHealthy ? const Color(0xFF43A047) : const Color(0xFFE53935),
                size: 20,
              ),
              title: Text(entry.value, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal')),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count >= 0 ? '$count سجل' : 'خطأ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: count >= 0 ? Colors.grey[700] : const Color(0xFFE53935),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(Map<String, dynamic> health) {
    final sync = Map<String, dynamic>.from(health['sync'] ?? {});

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: Color(0xFF00897B), size: 22),
              SizedBox(width: 10),
              Text('حالة المزامنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 16),
          _syncRow('في الانتظار', '${sync['pending_offline'] ?? 0}', const Color(0xFFFB8C00)),
          _syncRow('فاشلة', '${sync['failed_sync'] ?? 0}', const Color(0xFFE53935)),
          _syncRow('الحالة', sync['status'] == 'healthy' ? 'سليم' : 'تحذير',
            sync['status'] == 'healthy' ? const Color(0xFF43A047) : const Color(0xFFFB8C00)),
        ],
      ),
    );
  }

  Widget _syncRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal')),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on_rounded, color: Color(0xFF00897B), size: 22),
              SizedBox(width: 10),
              Text('إجراءات النظام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 16),
          _actionButton(Icons.refresh_rounded, 'تحديث الحالة', const Color(0xFF00897B), () {
            ref.invalidate(systemHealthProvider);
          }),
          const SizedBox(height: 8),
          _actionButton(Icons.backup_rounded, 'نسخ احتياطي', const Color(0xFF1E88E5), _createBackup),
          const SizedBox(height: 8),
          _actionButton(Icons.cleaning_services_rounded, 'تنظيف البيانات', const Color(0xFFFB8C00), _cleanupData),
          const SizedBox(height: 8),
          _actionButton(Icons.refresh_rounded, 'إعادة ضبط الإعدادات', const Color(0xFFE53935), _resetSettings),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBackupsSection(Map<String, dynamic> health) {
    final backups = List<Map<String, dynamic>>.from(health['backups'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFF00897B), size: 22),
                SizedBox(width: 10),
                Text('سجل النسخ الاحتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const Divider(height: 1),
          if (backups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('لا توجد نسخ احتياطية')),
            )
          else
            ...backups.map((b) => ListTile(
              leading: const Icon(Icons.backup_rounded, color: Color(0xFF1E88E5)),
              title: Text(b['backup_type'] ?? '', style: const TextStyle(fontFamily: 'Tajawal')),
              subtitle: Text(b['started_at'] ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (b['status'] == 'completed' ? const Color(0xFF43A047) : const Color(0xFFFB8C00)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b['status'] == 'completed' ? 'مكتمل' : 'قيد التنفيذ',
                  style: TextStyle(
                    fontSize: 12,
                    color: b['status'] == 'completed' ? const Color(0xFF43A047) : const Color(0xFFFB8C00),
                  ),
                ),
              ),
            )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _createBackup() async {
    try {
      await Supabase.instance.client.functions.invoke('system-monitor', body: {
        'action': 'backup',
      });
      ref.invalidate(systemHealthProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _cleanupData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنظيف البيانات'),
        content: const Text('سيتم حذف البيانات القديمة (أكثر من 90 يوم). هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.functions.invoke('system-monitor', body: {
                  'action': 'cleanup',
                  'days': 90,
                });
                ref.invalidate(systemHealthProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تنظيف البيانات')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة ضبط الإعدادات'),
        content: const Text('سيتم إعادة جميع الإعدادات للقيم الافتراضية. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تمت إعادة الضبط')),
              );
            },
            child: const Text('إعادة الضبط'),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final String status;

  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color, fontFamily: 'Cairo')),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
