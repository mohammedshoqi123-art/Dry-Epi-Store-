import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(length: 4, child: Scaffold(
      appBar: AppBar(title: const Text('حركات المخزون', style: TextStyle(fontFamily: 'Cairo')), centerTitle: true,
        bottom: const TabBar(tabs: [
          Tab(text: 'الكل'), Tab(text: 'استلام'), Tab(text: 'صرف'), Tab(text: 'تحويل'),
        ]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showNewMovementDialog(context))]),
      body: TabBarView(children: [
        _MovementList(filter: 'all'),
        _MovementList(filter: 'receipt'),
        _MovementList(filter: 'issue'),
        _MovementList(filter: 'transfer'),
      ]),
    ));
  }

  void _showNewMovementDialog(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حركة جديدة', style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.add_circle, color: Colors.green), title: const Text('استلام مخزون', style: TextStyle(fontFamily: 'Tajawal')),
          onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.remove_circle, color: Colors.red), title: const Text('صرف مخزون', style: TextStyle(fontFamily: 'Tajawal')),
          onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.compare_arrows, color: Colors.blue), title: const Text('تحويل بين المخازن', style: TextStyle(fontFamily: 'Tajawal')),
          onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.qr_code_scanner, color: Colors.purple), title: const Text('مسح QR للتسجيل', style: TextStyle(fontFamily: 'Tajawal')),
          onTap: () => Navigator.pop(ctx)),
        const SizedBox(height: 16),
      ]),
    ));
  }
}

class _MovementList extends StatelessWidget {
  final String filter;
  const _MovementList({required this.filter});
  @override
  Widget build(BuildContext context) {
    final movements = [
      {'num': 'MOV-26-000045', 'type': 'receipt', 'item': 'لقاح BCG', 'qty': 500, 'from': 'المستودع المركزي', 'to': 'مخزن صنعاء', 'status': 'مكتمل', 'time': '2026-04-17 09:30', 'statusColor': Colors.green},
      {'num': 'MOV-26-000044', 'type': 'issue', 'item': 'محاقن 0.5ml', 'qty': 200, 'from': 'مخزن صنعاء', 'to': 'مركز صحي السبعين', 'status': 'مكتمل', 'time': '2026-04-17 08:15', 'statusColor': Colors.green},
      {'num': 'MOV-26-000043', 'type': 'transfer', 'item': 'لقاح OPV', 'qty': 1000, 'from': 'المستودع المركزي', 'to': 'مخزن عدن', 'status': 'قيد الانتظار', 'time': '2026-04-17 07:00', 'statusColor': Colors.orange},
      {'num': 'MOV-26-000042', 'type': 'receipt', 'item': 'لقاح Penta', 'qty': 3000, 'from': 'يونيسف', 'to': 'المستودع المركزي', 'status': 'مكتمل', 'time': '2026-04-16 14:20', 'statusColor': Colors.green},
      {'num': 'MOV-26-000041', 'type': 'issue', 'item': 'صندوق حفظ بارد', 'qty': 5, 'from': 'مخزن تعز', 'to': 'مراكز ميدانية', 'status': 'مرفوض', 'time': '2026-04-16 11:00', 'statusColor': Colors.red},
    ];
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: movements.length, itemBuilder: (ctx, i) {
      final m = movements[i];
      IconData typeIcon; Color typeColor;
      switch(m['type']) { case 'receipt': typeIcon = Icons.add_circle; typeColor = Colors.green; break;
        case 'issue': typeIcon = Icons.remove_circle; typeColor = Colors.red; break;
        default: typeIcon = Icons.compare_arrows; typeColor = Colors.blue; }
      return Card(margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: typeColor.withValues(alpha: 0.2), child: Icon(typeIcon, color: typeColor)),
        title: Text('${m['num']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${m['item']} — ${m['qty']} وحدة', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: (m['statusColor'] as Color).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: Text(m['status'].toString(), style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: m['statusColor'] as Color))),
        children: [Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('من: ${m['from']}', style: const TextStyle(fontFamily: 'Tajawal')),
          Text('إلى: ${m['to']}', style: const TextStyle(fontFamily: 'Tajawal')),
          Text('الوقت: ${m['time']}', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
        ]))],
      ));
    });
  }
}
