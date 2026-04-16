import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates PDF reports per form with Arabic support, stats, and tables.
class FormReportGenerator {
  /// Generate a detailed PDF report for a specific form.
  static Future<File> generate({
    required Map<String, dynamic> form,
    required List<Map<String, dynamic>> submissions,
    required String period,
  }) async {
    final pdf = pw.Document();

    // Load Arabic fonts
    final arabicFontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final arabicFont = pw.Font.ttf(arabicFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final stats = _computeStats(submissions);

    // Page 1: Summary
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              form['title_ar'] ?? form['title'] ?? 'تقرير الاستمارة',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 24),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'الفترة: $period',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: arabicFont, fontSize: 14),
            ),
            pw.SizedBox(height: 20),
            _statsGrid(stats, arabicFont, boldFont),
            pw.SizedBox(height: 20),
            pw.Text(
              'تاريخ التقرير: ${DateTime.now().toIso8601String().substring(0, 10)}',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: arabicFont, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    // Page 2+: Submissions table
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
          _submissionsTable(submissions.take(100).toList(), arabicFont),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${form['id']}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generate raw PDF bytes (for sharing without saving to file)
  static Future<Uint8List> generateBytes({
    required Map<String, dynamic> form,
    required List<Map<String, dynamic>> submissions,
    required String period,
  }) async {
    final pdf = pw.Document();
    final arabicFontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final arabicFont = pw.Font.ttf(arabicFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final stats = _computeStats(submissions);

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              form['title_ar'] ?? form['title'] ?? 'تقرير الاستمارة',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 24),
            ),
            pw.SizedBox(height: 12),
            _statsGrid(stats, arabicFont, boldFont),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _statsGrid(
    Map<String, dynamic> stats,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard('إجمالي الإرساليات', '${stats['total']}', font, boldFont),
        _statCard('إرسالاليات اليوم', '${stats['today']}', font, boldFont),
        _statCard(
            'نسبة الإنجاز', '${stats['completionRate']}%', font, boldFont),
        _statCard('مرفوضة', '${stats['rejected']}', font, boldFont),
      ],
    );
  }

  static pw.Widget _statCard(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: boldFont, fontSize: 20)),
          pw.SizedBox(height: 4),
          pw.Text(label,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _submissionsTable(
      List<Map<String, dynamic>> subs, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: font, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      headers: ['التاريخ', 'الحالة', 'الجهة'],
      data: subs
          .map((s) => [
                (s['created_at'] ?? '').toString().substring(0, 10),
                s['status'] ?? '-',
                s['facility_name'] ?? '-',
              ])
          .toList(),
    );
  }

  static Map<String, dynamic> _computeStats(List<Map<String, dynamic>> subs) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCount =
        subs.where((s) => (s['created_at'] ?? '').startsWith(today)).length;
    final submitted = subs.where((s) => s['status'] == 'submitted').length;
    final rejected = subs.where((s) => s['status'] == 'rejected').length;

    return {
      'total': subs.length,
      'today': todayCount,
      'completionRate': subs.isEmpty ? 0 : (submitted * 100 ~/ subs.length),
      'rejected': rejected,
    };
  }
}
