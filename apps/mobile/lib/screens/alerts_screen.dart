import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = [
      {'type': 'low_stock', 'severity': 'critical', 'title': 'نقص حرج — لقاح Penta', 'message': 'الكمية المتبقية: 3 جرعات فقط في مخزن صنعاء', 'time': 'منذ ساعة', 'icon': Icons.error, 'color': Colors.red},
      {'type': 'expiry', 'severity': 'high', 'title': 'اقتراب انتهاء الصلاحية', 'message': 'دفعة OPV-2026-012 ستنتهي خلال 15 يوم', 'time': 'منذ 3 ساعات', 'icon': Icons.timer, 'color': Colors.orange},
      {'type': 'low_stock', 'severity': 'high', 'title': 'نقص — محاقن 5ml', 'message': 'الكمية الحالية: 150 قطعة، أقل من الحد الأدنى', 'time': 'منذ 5 ساعات', 'icon': Icons.warning, 'color': Colors.orange},
      {'type': 'transfer', 'severity': 'medium', 'title': 'تحويل معلق', 'message': 'تحويل 1000 جرعة OPV من المركزي إلى عدن — بانتظار الموافقة', 'time': 'منذ يوم', 'icon': Icons.hourglass_empty, 'color': Colors.blue},
      {'type': 'expired', 'severity': 'critical', 'title': 'منتج منتهي الصلاحية', 'message': 'دفعة BCG-2025-088 انتهت صلاحيتها', 'time': 'منذ يومين', 'icon': Icons.block, 'color': Colors.red},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('التنبيهات', style: TextStyle(fontFamily: 'Cairo')), centerTitle: true,
        actions: [Badge(label: const Text('5'), child: IconButton(icon: const Icon(Icons.notifications), onPressed: () {}))]),
      body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: alerts.length, itemBuilder: (ctx, i) {
        final a = alerts[i];
        return Card(margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(side: BorderSide(color: (a['color'] as Color).withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: (a['color'] as Color).withValues(alpha: 0.2), child: Icon(a['icon'] as IconData, color: a['color'] as Color)),
            title: Text(a['title'].toString(), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['message'].toString(), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
              const SizedBox(height: 4),
              Text(a['time'].toString(), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey)),
            ]),
            isThreeLine: true,
            trailing: IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () {}),
          ));
      }),
    );
  }
}
