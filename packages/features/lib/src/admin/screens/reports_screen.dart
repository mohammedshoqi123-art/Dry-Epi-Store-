import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

/// ═══════════════════════════════════════════════════════════════════
///  التقارير والتحليلات — Reports & Analytics
/// ═══════════════════════════════════════════════════════════════════

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _reportType = 'submissions';
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildReportControls(),
        const SizedBox(height: 16),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reportData == null
                    ? _buildEmptyState()
                    : _buildReportContent()),
      ],
    );
  }

  Widget _buildReportControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          // Report type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportType,
                items: const [
                  DropdownMenuItem(
                      value: 'submissions', child: Text('الإرساليات')),
                  DropdownMenuItem(
                      value: 'governorate_performance',
                      child: Text('أداء المحافظات')),
                  DropdownMenuItem(value: 'users', child: Text('المستخدمين')),
                  DropdownMenuItem(value: 'shortages', child: Text('النواقص')),
                  DropdownMenuItem(value: 'audit', child: Text('سجل التدقيق')),
                ],
                onChanged: (v) => setState(() => _reportType = v!),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Date range
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
              );
              if (picked != null) {
                setState(() {
                  _fromDate = picked.start;
                  _toDate = picked.end;
                });
              }
            },
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(
              '${_fromDate.year}/${_fromDate.month}/${_fromDate.day} - ${_toDate.year}/${_toDate.month}/${_toDate.day}',
            ),
          ),
          const SizedBox(width: 16),

          // Generate button
          ElevatedButton.icon(
            onPressed: _generateReport,
            icon: const Icon(Icons.assessment_rounded),
            label: const Text('إنشاء التقرير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(width: 12),

          // Export
          if (_reportData != null)
            OutlinedButton.icon(
              onPressed: _exportReport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('تصدير'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'اختر نوع التقرير والفترة الزمنية ثم اضغط "إنشاء التقرير"',
            style: TextStyle(
                fontSize: 16, color: Colors.grey[500], fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_reportType) {
      case 'governorate_performance':
        return _buildGovernoratePerformance();
      case 'users':
        return _buildUsersReport();
      case 'shortages':
        return _buildShortagesReport();
      default:
        return _buildSubmissionsReport();
    }
  }

  Widget _buildSubmissionsReport() {
    final submissions =
        List<Map<String, dynamic>>.from(_reportData?['submissions'] ?? []);
    final aggregates =
        Map<String, dynamic>.from(_reportData?['aggregates'] ?? {});
    final total = _reportData?['total'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary cards
          Row(
            children: [
              _SummaryCard('إجمالي', '$total', const Color(0xFF00897B)),
              _SummaryCard(
                  'مقبول',
                  '${aggregates['by_status']?['approved'] ?? 0}',
                  const Color(0xFF43A047)),
              _SummaryCard(
                  'مرفوض',
                  '${aggregates['by_status']?['rejected'] ?? 0}',
                  const Color(0xFFE53935)),
              _SummaryCard(
                  'معلق',
                  '${aggregates['by_status']?['submitted'] ?? 0}',
                  const Color(0xFFFB8C00)),
            ],
          ),
          const SizedBox(height: 16),

          // Submissions table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('الاستمارة')),
                  DataColumn(label: Text('المقدم')),
                  DataColumn(label: Text('المحافظة')),
                  DataColumn(label: Text('التاريخ')),
                ],
                rows: submissions
                    .take(50)
                    .map((s) => DataRow(cells: [
                          DataCell(_statusChip(s['status'])),
                          DataCell(Text(s['forms']?['title_ar'] ?? '')),
                          DataCell(Text(s['profiles']?['full_name'] ?? '')),
                          DataCell(Text(s['governorates']?['name_ar'] ?? '')),
                          DataCell(Text((s['created_at'] as String? ?? '')
                              .split('T')
                              .first)),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernoratePerformance() {
    final govs =
        List<Map<String, dynamic>>.from(_reportData?['governorates'] ?? []);

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المحافظة')),
              DataColumn(label: Text('الإرساليات'), numeric: true),
              DataColumn(label: Text('مقبول'), numeric: true),
              DataColumn(label: Text('مرفوض'), numeric: true),
              DataColumn(label: Text('معدل القبول'), numeric: true),
              DataColumn(label: Text('المديريات'), numeric: true),
              DataColumn(label: Text('المنشآت'), numeric: true),
              DataColumn(label: Text('المستخدمون'), numeric: true),
            ],
            rows: govs.map((g) {
              final sub = Map<String, dynamic>.from(g['submissions'] ?? {});
              return DataRow(cells: [
                DataCell(Text(g['name_ar'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('${sub['total'] ?? 0}')),
                DataCell(Text('${sub['approved'] ?? 0}')),
                DataCell(Text('${sub['rejected'] ?? 0}')),
                DataCell(Text('${sub['approval_rate'] ?? 0}%')),
                DataCell(Text('${g['districts'] ?? 0}')),
                DataCell(Text('${g['facilities'] ?? 0}')),
                DataCell(Text('${g['users'] ?? 0}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersReport() {
    final users = List<Map<String, dynamic>>.from(_reportData?['users'] ?? []);
    final aggregates =
        Map<String, dynamic>.from(_reportData?['aggregates'] ?? {});
    final byRole = Map<String, dynamic>.from(aggregates['by_role'] ?? {});

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: byRole.entries
                .map((e) => Expanded(
                      child: _SummaryCard(
                          _roleLabel(e.key), '${e.value}', _roleColor(e.key)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('البريد')),
                  DataColumn(label: Text('الدور')),
                  DataColumn(label: Text('المحافظة')),
                  DataColumn(label: Text('نشط')),
                ],
                rows: users
                    .take(50)
                    .map((u) => DataRow(cells: [
                          DataCell(Text(u['full_name'] ?? '')),
                          DataCell(Text(u['email'] ?? '')),
                          DataCell(Text(_roleLabel(u['role']))),
                          DataCell(Text(u['governorates']?['name_ar'] ?? '')),
                          DataCell(Text(u['is_active'] == true ? 'نعم' : 'لا')),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortagesReport() {
    final shortages =
        List<Map<String, dynamic>>.from(_reportData?['shortages'] ?? []);

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('الصنف')),
              DataColumn(label: Text('الخطورة')),
              DataColumn(label: Text('المطلوب')),
              DataColumn(label: Text('المتاح')),
              DataColumn(label: Text('المحافظة')),
              DataColumn(label: Text('محلول')),
            ],
            rows: shortages
                .take(50)
                .map((s) => DataRow(cells: [
                      DataCell(Text(s['item_name'] ?? '')),
                      DataCell(_severityChip(s['severity'])),
                      DataCell(Text('${s['quantity_needed'] ?? 0}')),
                      DataCell(Text('${s['quantity_available'] ?? 0}')),
                      DataCell(Text(s['governorates']?['name_ar'] ?? '')),
                      DataCell(Text(s['is_resolved'] == true ? '✓' : '✗')),
                    ]))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = const Color(0xFF43A047);
        label = 'مقبول';
        break;
      case 'rejected':
        color = const Color(0xFFE53935);
        label = 'مرفوض';
        break;
      case 'submitted':
        color = const Color(0xFFFB8C00);
        label = 'معلق';
        break;
      case 'reviewed':
        color = const Color(0xFF1E88E5);
        label = 'تمت المراجعة';
        break;
      default:
        color = Colors.grey;
        label = status ?? '';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _severityChip(String? severity) {
    Color color;
    switch (severity) {
      case 'critical':
        color = const Color(0xFFB71C1C);
        break;
      case 'high':
        color = const Color(0xFFE53935);
        break;
      case 'medium':
        color = const Color(0xFFFB8C00);
        break;
      default:
        color = const Color(0xFF43A047);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(severity ?? '',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مسؤول';
      case 'central':
        return 'مركزي';
      case 'governorate':
        return 'محافظة';
      case 'district':
        return 'مديرية';
      case 'data_entry':
        return 'إدخال بيانات';
      default:
        return role ?? '';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFE53935);
      case 'central':
        return const Color(0xFF8E24AA);
      case 'governorate':
        return const Color(0xFF1E88E5);
      case 'district':
        return const Color(0xFFFB8C00);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  void _generateReport() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.functions
          .invoke('get-advanced-reports', body: {
        'report_type': _reportType,
        'from_date': _fromDate.toIso8601String(),
        'to_date': _toDate.toIso8601String(),
      });
      setState(() {
        _reportData = Map<String, dynamic>.from(response.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _exportReport() async {
    try {
      await Supabase.instance.client.functions.invoke('export-data', body: {
        'table': _reportType == 'governorate_performance'
            ? 'submissions'
            : _reportType,
        'from_date': _fromDate.toIso8601String(),
        'to_date': _toDate.toIso8601String(),
        'format': 'csv',
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تصدير التقرير')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _SummaryCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Cairo')),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}
