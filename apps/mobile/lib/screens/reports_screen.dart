import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير', style: TextStyle(fontFamily: 'Cairo')), centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Report Types
        const Text('أنواع التقارير', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _ReportCard(icon: Icons.inventory, label: 'تقرير المخزون', color: const Color(0xFF0D7C66)),
          _ReportCard(icon: Icons.swap_horiz, label: 'تقرير الحركات', color: const Color(0xFF1565C0)),
          _ReportCard(icon: Icons.access_time, label: 'تقرير الصلاحية', color: const Color(0xFFFF6D00)),
          _ReportCard(icon: Icons.map, label: 'توزيع جغرافي', color: const Color(0xFF7B1FA2)),
          _ReportCard(icon: Icons.bar_chart, label: 'استهلاك شهري', color: const Color(0xFF00838F)),
          _ReportCard(icon: Icons.download, label: 'تصدير PDF', color: const Color(0xFFD32F2F)),
        ]),
        const SizedBox(height: 24),

        // Monthly Consumption Chart
        const Text('استهلاك اللقاحات — آخر 6 أشهر', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 200, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 5000,
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 3500, color: const Color(0xFF0D7C66))]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 4200, color: const Color(0xFF0D7C66))]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 3800, color: const Color(0xFF0D7C66))]),
            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 4500, color: const Color(0xFF0D7C66))]),
            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 3200, color: const Color(0xFF0D7C66))]),
            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 4100, color: const Color(0xFF1565C0))]),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              const months = ['نوف', 'ديس', 'ينا', 'فبر', 'مار', 'أبر'];
              return Text(months[v.toInt()], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10));
            })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ))),
      ])),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _ReportCard({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: () {}, borderRadius: BorderRadius.circular(12),
      child: Container(width: 150, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: color), textAlign: TextAlign.center)]),
      ),
    );
  }
}
