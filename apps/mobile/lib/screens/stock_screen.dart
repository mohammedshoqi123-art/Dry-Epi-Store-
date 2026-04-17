import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('المخزون', style: TextStyle(fontFamily: 'Cairo')), centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})]),
      body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _items.length, itemBuilder: (ctx, i) {
        final item = _items[i];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
          leading: CircleAvatar(backgroundColor: item['color'], child: Icon(item['icon'], color: Colors.white)),
          title: Text(item['name'], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          subtitle: Text('${item['category']} — دفعة: ${item['batch']}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${item['qty']}', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: item['qtyColor'])),
            Text(item['unit'], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey)),
          ]),
          onTap: () {}),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.qr_code_scanner), label: const Text('مسح QR', style: TextStyle(fontFamily: 'Tajawal'))),
    );
  }
}

final _items = [
  {'name': 'لقاح BCG', 'category': 'لقاحات', 'batch': 'BCG-2026-001', 'qty': 2500, 'qtyColor': Colors.green, 'unit': 'جرعة', 'icon': Icons.vaccines, 'color': const Color(0xFF0D7C66)},
  {'name': 'لقاح OPV', 'category': 'لقاحات', 'batch': 'OPV-2026-015', 'qty': 5000, 'qtyColor': Colors.green, 'unit': 'جرعة', 'icon': Icons.vaccines, 'color': const Color(0xFF0D7C66)},
  {'name': 'لقاح Penta', 'category': 'لقاحات', 'batch': 'PEN-2026-008', 'qty': 3, 'qtyColor': Colors.red, 'unit': 'جرعة', 'icon': Icons.vaccines, 'color': const Color(0xFFD32F2F)},
  {'name': 'محاقن 0.5ml', 'category': 'محاقن', 'batch': 'SYR-2026-042', 'qty': 8000, 'qtyColor': Colors.green, 'unit': 'قطعة', 'icon': Icons.medical_services, 'color': const Color(0xFF1565C0)},
  {'name': 'محاقن 5ml', 'category': 'محاقن', 'batch': 'SYR-2026-033', 'qty': 150, 'qtyColor': Colors.orange, 'unit': 'قطعة', 'icon': Icons.medical_services, 'color': const Color(0xFFFF6D00)},
  {'name': 'صندوق حفظ بارد', 'category': 'مستلزمات', 'batch': 'CB-2026-005', 'qty': 12, 'qtyColor': Colors.green, 'unit': 'صندوق', 'icon': Icons.ac_unit, 'color': const Color(0xFF7B1FA2)},
  {'name': 'مواد تعقيم', 'category': 'مستلزمات', 'batch': 'DIS-2026-019', 'qty': 45, 'qtyColor': Colors.green, 'unit': 'عبوة', 'icon': Icons.cleaning_services, 'color': const Color(0xFF00838F)},
];
