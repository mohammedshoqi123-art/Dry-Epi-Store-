import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dry_shared/dry_shared.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                Expanded(child: _KpiCard(icon: Icons.inventory_2, label: 'إجمالي المخزون', value: '12,450', color: const Color(0xFF0D7C66))),
                const SizedBox(width: 12),
                Expanded(child: _KpiCard(icon: Icons.warning_amber, label: 'تنبيهات نشطة', value: '8', color: const Color(0xFFFF6D00))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _KpiCard(icon: Icons.swap_horiz, label: 'حركات اليوم', value: '23', color: const Color(0xFF1565C0))),
                const SizedBox(width: 12),
                Expanded(child: _KpiCard(icon: Icons.warehouse, label: 'المخازن النشطة', value: '5', color: const Color(0xFF7B1FA2))),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text('إجراءات سريعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _QuickAction(icon: Icons.add_circle, label: 'استلام', color: Colors.green, onTap: () => context.go('/movements')),
                _QuickAction(icon: Icons.remove_circle, label: 'صرف', color: Colors.red, onTap: () => context.go('/movements')),
                _QuickAction(icon: Icons.compare_arrows, label: 'تحويل', color: Colors.blue, onTap: () => context.go('/movements')),
                _QuickAction(icon: Icons.qr_code_scanner, label: 'مسح QR', color: Colors.purple, onTap: () {}),
                _QuickAction(icon: Icons.analytics, label: 'تقارير', color: Colors.teal, onTap: () => context.go('/reports')),
                _QuickAction(icon: Icons.notifications, label: 'تنبيهات', color: Colors.orange, onTap: () => context.go('/alerts')),
              ],
            ),
            const SizedBox(height: 24),

            // Stock Distribution Chart
            const Text('توزيع المخزون', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: 40, color: const Color(0xFF0D7C66), title: 'لقاحات', radius: 60, titleStyle: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
                  PieChartSectionData(value: 25, color: const Color(0xFF1565C0), title: 'محاقن', radius: 55, titleStyle: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
                  PieChartSectionData(value: 20, color: const Color(0xFFFF6D00), title: 'مستلزمات', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
                  PieChartSectionData(value: 15, color: const Color(0xFF7B1FA2), title: 'أخرى', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
                ],
              )),
            ),
            const SizedBox(height: 24),

            // Recent Movements
            const Text('آخر الحركات', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MovementTile(type: 'استلام', item: 'لقاح BCG', qty: '500', time: 'منذ ساعة', color: Colors.green),
            _MovementTile(type: 'صرف', item: 'محاقن 0.5ml', qty: '200', time: 'منذ 3 ساعات', color: Colors.red),
            _MovementTile(type: 'تحويل', item: 'لقاح OPV', qty: '1000', time: 'منذ 5 ساعات', color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(width: 100, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 6), Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: color))]),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final String type, item, qty, time; final Color color;
  const _MovementTile({required this.type, required this.item, required this.qty, required this.time, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Text(type[0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      title: Text('$type — $item', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
      subtitle: Text(time, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
      trailing: Text('$qty وحدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: color)),
    ));
  }
}
