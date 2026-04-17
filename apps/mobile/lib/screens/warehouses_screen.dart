import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = [
      {'name': 'المستودع المركزي', 'code': 'WH-CEN', 'gov': 'أمانة العاصمة', 'items': 12450, 'capacity': 85, 'color': const Color(0xFF0D7C66)},
      {'name': 'مخزن صنعاء', 'code': 'WH-SAN', 'gov': 'صنعاء', 'items': 3200, 'capacity': 62, 'color': const Color(0xFF1565C0)},
      {'name': 'مخزن عدن', 'code': 'WH-ADE', 'gov': 'عدن', 'items': 2800, 'capacity': 55, 'color': const Color(0xFFFF6D00)},
      {'name': 'مخزن تعز', 'code': 'WH-TAZ', 'gov': 'تعز', 'items': 1500, 'capacity': 40, 'color': const Color(0xFF7B1FA2)},
      {'name': 'مخزن الحديدة', 'code': 'WH-HOD', 'gov': 'الحديدة', 'items': 2100, 'capacity': 48, 'color': const Color(0xFF00838F)},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('المخازن', style: TextStyle(fontFamily: 'Cairo')), centerTitle: true),
      body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: warehouses.length, itemBuilder: (ctx, i) {
        final w = warehouses[i];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: w['color'] as Color, child: const Icon(Icons.warehouse, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w['name'].toString(), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${w['code']} — ${w['gov']}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${w['items']} عنصر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: w['color'] as Color)),
                const Text('إجمالي الأصناف', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey)),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LinearProgressIndicator(value: (w['capacity'] as int) / 100, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(w['color'] as Color)),
                const SizedBox(height: 4),
                Text('السعة: ${w['capacity']}%', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey)),
              ])),
            ]),
          ],
        )));
      }),
    );
  }
}
