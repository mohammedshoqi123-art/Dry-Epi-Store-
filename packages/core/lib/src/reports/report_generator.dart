import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Advanced report generator with PDF export.
/// Supports Arabic text, charts, tables, and KPI cards.
class ReportGenerator {
  /// Generate a full PDF report with sections
  static Future<File> generatePDFReport({
    required String title,
    required String period,
    required List<Map<String, dynamic>> submissions,
    required Map<String, dynamic> stats,
    List<String>? recommendations,
    String? outputPath,
  }) async {
    final pdf = pw.Document();

    // Load Arabic fonts
    final arabicFontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final arabicFont = pw.Font.ttf(arabicFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    // Page 1: Cover + Summary
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Header
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                title,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                    font: boldFont, fontSize: 28, color: PdfColors.blue800),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'الفترة: $period',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: arabicFont, fontSize: 14),
              ),
            ),
            pw.SizedBox(height: 30),
            // Stats grid
            _buildStatsGrid(stats, arabicFont, boldFont),
            pw.SizedBox(height: 30),
            // Summary text
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ملخص تنفيذي',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                        font: boldFont, fontSize: 16, color: PdfColors.blue800),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'تم إنشاء هذا التقرير تلقائياً بواسطة "EPI Supervisors",',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: arabicFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'تاريخ الإنشاء: ${DateTime.now().toIso8601String().substring(0, 10)}',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                        font: arabicFont, fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Page 2: Status Distribution
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'توزيع الإرساليات حسب الحالة',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
            pw.SizedBox(height: 16),
            _buildStatusChart(stats, arabicFont, boldFont),
            pw.SizedBox(height: 30),
            // Top areas
            pw.Text(
              'أداء المحافظات',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
            pw.SizedBox(height: 16),
            _buildAreaPerformanceTable(submissions, arabicFont, boldFont),
          ],
        ),
      ),
    );

    // Page 3+: Submissions details
    if (submissions.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
          build: (ctx) => [
            pw.Text(
              'تفاصيل الإرساليات',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
            pw.SizedBox(height: 12),
            _buildSubmissionsTable(
                submissions.take(200).toList(), arabicFont, boldFont),
          ],
        ),
      );
    }

    // Recommendations page
    if (recommendations != null && recommendations.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'التوصيات',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 16),
              ...recommendations.map((rec) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          right: pw.BorderSide(
                              color: PdfColors.blue400, width: 3),
                        ),
                      ),
                      child: pw.Text(
                        rec,
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(font: arabicFont, fontSize: 12),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );
    }

    // Save
    final dir = await getTemporaryDirectory();
    final file = File(outputPath ??
        '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generate raw PDF bytes for sharing
  static Future<Uint8List> generateBytes({
    required String title,
    required String period,
    required List<Map<String, dynamic>> submissions,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();
    final arabicFontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData =
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final arabicFont = pw.Font.ttf(arabicFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(title,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: boldFont, fontSize: 24)),
            pw.SizedBox(height: 12),
            _buildStatsGrid(stats, arabicFont, boldFont),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildStatsGrid(
      Map<String, dynamic> stats, pw.Font font, pw.Font boldFont) {
    final items = [
      {'label': 'إجمالي الإرساليات', 'value': '${stats['total'] ?? 0}'},
      {'label': 'إرساليات اليوم', 'value': '${stats['today'] ?? 0}'},
      {
        'label': 'نسبة الإنجاز',
        'value': '${stats['completionRate'] ?? 0}%'
      },
      {'label': 'مرفوضة', 'value': '${stats['rejected'] ?? 0}'},
      {'label': 'قيد الانتظار', 'value': '${stats['pending'] ?? 0}'},
    ];

    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) => pw.Container(
                width: 140,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      item['value']!,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 22, color: PdfColors.blue800),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      item['label']!,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                          font: font, fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _buildStatusChart(
      Map<String, dynamic> stats, pw.Font font, pw.Font boldFont) {
    final byStatus = stats['byStatus'] as Map<String, dynamic>? ?? {};
    if (byStatus.isEmpty) {
      return pw.Text('لا توجد بيانات',
          textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: font));
    }

    final total = byStatus.values.fold(0, (sum, v) => sum + (v as int));
    if (total == 0) return pw.SizedBox();

    final colors = [
      PdfColors.green400,
      PdfColors.red400,
      PdfColors.orange400,
      PdfColors.blue400,
      PdfColors.grey400,
    ];
    final statusLabels = {
      'submitted': 'مقبول',
      'rejected': 'مرفوض',
      'pending': 'قيد الانتظار',
      'draft': 'مسودة',
    };

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: byStatus.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value.key;
        final count = entry.value.value as int;
        final pct = (count * 100 / total).toStringAsFixed(1);

        return pw.Column(
          children: [
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                color: colors[index % colors.length],
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  '$pct%',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    font: boldFont,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              statusLabels[status] ?? status,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.Text(
              '$count',
              style: pw.TextStyle(
                  font: boldFont, fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _buildAreaPerformanceTable(
      List<Map<String, dynamic>> subs, pw.Font font, pw.Font boldFont) {
    // Group by governorate
    final byGov = <String, Map<String, int>>{};
    for (final s in subs) {
      final gov = s['governorate_name'] ?? 'غير محدد';
      byGov.putIfAbsent(gov, () => {'total': 0, 'submitted': 0});
      byGov[gov]!['total'] = byGov[gov]!['total']! + 1;
      if (s['status'] == 'submitted') {
        byGov[gov]!['submitted'] = byGov[gov]!['submitted']! + 1;
      }
    }

    final sorted = byGov.entries.toList()
      ..sort((a, b) => b.value['submitted']!.compareTo(a.value['submitted']!));

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      headers: ['المحافظة', 'الإجمالي', 'مقبول', 'النسبة'],
      data: sorted
          .take(15)
          .map((e) => [
                e.key,
                '${e.value['total']}',
                '${e.value['submitted']}',
                '${e.value['total']! > 0 ? (e.value['submitted']! * 100 ~/ e.value['total']!) : 0}%'
              ])
          .toList(),
    );
  }

  static pw.Widget _buildSubmissionsTable(
      List<Map<String, dynamic>> subs, pw.Font font, pw.Font boldFont) {
    final statusLabels = {
      'submitted': 'مقبول',
      'rejected': 'مرفوض',
      'pending': 'قيد الانتظار',
      'draft': 'مسودة',
    };

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignment: pw.Alignment.centerRight,
      headers: ['#', 'التاريخ', 'الحالة', 'الجهة', 'المحافظة'],
      data: subs
          .asMap()
          .entries
          .map((e) => [
                '${e.key + 1}',
                (e.value['created_at'] ?? '').toString().substring(0, 10),
                statusLabels[e.value['status']] ?? e.value['status'] ?? '-',
                e.value['facility_name'] ?? '-',
                e.value['governorate_name'] ?? '-',
              ])
          .toList(),
    );
  }
}
