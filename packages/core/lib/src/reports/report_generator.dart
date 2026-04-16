import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ═══════════════════════════════════════════════════════════════════════
/// Professional PDF Report Generator for EPI Supervisor
/// Supports Arabic RTL, branded design, KPI cards, tables, charts
/// ═══════════════════════════════════════════════════════════════════════
class ReportGenerator {
  // Brand colors
  static const _primaryColor = PdfColor.fromInt(0xFF00897B);
  static const _primaryDark = PdfColor.fromInt(0xFF004D40);
  static const _accentColor = PdfColor.fromInt(0xFFE53935);
  static const _successColor = PdfColor.fromInt(0xFF43A047);
  static const _warningColor = PdfColor.fromInt(0xFFFF8F00);
  static const _bgLight = PdfColor.fromInt(0xFFF5F7FA);
  static const _textDark = PdfColor.fromInt(0xFF212121);
  static const _textMuted = PdfColor.fromInt(0xFF757575);

  static pw.Font? _font;
  static pw.Font? _boldFont;
  static pw.Font? _lightFont;

  /// Generate a full professional PDF report
  static Future<File> generatePDFReport({
    required String title,
    required String subtitle,
    required String period,
    required Map<String, dynamic> analyticsData,
    List<Map<String, dynamic>>? governorateData,
    List<Map<String, dynamic>>? shortagesData,
    String? outputPath,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final submissions = analyticsData['submissions'] as Map<String, dynamic>? ?? {};
    final shortages = analyticsData['shortages'] as Map<String, dynamic>? ?? {};
    final total = submissions['total'] as int? ?? 0;
    final today = submissions['today'] as int? ?? 0;
    final byStatus = submissions['byStatus'] as Map<String, dynamic>? ?? {};
    final byDay = submissions['byDay'] as Map<String, dynamic>? ?? {};
    final totalShortages = shortages['total'] as int? ?? 0;
    final resolvedShortages = shortages['resolved'] as int? ?? 0;
    final bySeverity = shortages['bySeverity'] as Map<String, dynamic>? ?? {};

    final approved = byStatus['approved'] as int? ?? 0;
    final rejected = byStatus['rejected'] as int? ?? 0;
    final pending = byStatus['submitted'] as int? ?? 0;
    final draft = byStatus['draft'] as int? ?? 0;
    final completionRate = total > 0 ? ((approved / total) * 100).round() : 0;
    final shortageRate = totalShortages > 0 ? ((resolvedShortages / totalShortages) * 100).round() : 0;

    // ═══ Page 1: Cover Page ═══
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        theme: pw.ThemeData.withFont(base: _font!, bold: _boldFont!),
        build: (ctx) => pw.Stack(
          children: [
            // Background gradient header
            pw.Positioned(
              top: 0, left: 0, right: 0,
              child: pw.Container(
                height: 280,
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [_primaryColor, _primaryDark],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Content
            pw.Column(
              children: [
                pw.SizedBox(height: 60),
                // Logo area
                pw.Container(
                  width: 80, height: 80,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text('🏥', style: pw.TextStyle(fontSize: 36)),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'منصة مشرف EPI',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: _boldFont, fontSize: 28, color: PdfColors.white),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'نظام الإشراف الميداني لحملات التطعيم',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: _lightFont, fontSize: 14, color: PdfColor.fromInt(0xB3FFFFFF)),
                ),
                pw.SizedBox(height: 40),
                // Report card
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 40),
                  padding: const pw.EdgeInsets.all(30),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(16),
                    boxShadow: [
                      pw.BoxShadow(color: PdfColor.fromInt(0x1A000000), blurRadius: 20, offset: const PdfPoint(0, 4)),
                    ],
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _primaryColor,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text('تقرير', style: pw.TextStyle(font: _boldFont, fontSize: 12, color: PdfColors.white)),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        title,
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(font: _boldFont, fontSize: 22, color: _textDark),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        subtitle,
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(font: _font, fontSize: 13, color: _textMuted),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0)),
                      pw.SizedBox(height: 16),
                      // Meta info
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          _metaItem('📅 الفترة', period, _font!),
                          _metaItem('📊 الإجمالي', '$total إرسالية', _font!),
                          _metaItem('✅ الإنجاز', '$completionRate%', _font!),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('تاريخ الإنشاء: $dateStr  $timeStr',
                        style: pw.TextStyle(font: _lightFont, fontSize: 9, color: _textMuted)),
                      pw.Text('EPI Supervisor v2.1.0',
                        style: pw.TextStyle(font: _lightFont, fontSize: 9, color: _textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // ═══ Page 2: KPI Summary ═══
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        theme: pw.ThemeData.withFont(base: _font!, bold: _boldFont!),
        header: (ctx) => _buildHeader(title, dateStr),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          // Section title
          _sectionHeader('📋 ملخص المؤشرات الرئيسية'),
          pw.SizedBox(height: 16),

          // KPI Cards Grid
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiCard('إجمالي الإرساليات', '$total', _primaryColor),
              _kpiCard('إرساليات اليوم', '$today', PdfColors.blue700),
              _kpiCard('مقبول', '$approved', _successColor),
              _kpiCard('مرفوض', '$rejected', _accentColor),
              _kpiCard('قيد المراجعة', '$pending', _warningColor),
              _kpiCard('مسودات', '$draft', PdfColors.grey600),
              _kpiCard('نسبة القبول', '$completionRate%', _successColor),
              _kpiCard('النواقص', '$totalShortages', _warningColor),
              _kpiCard('نواقص محلولة', '$resolvedShortages', _successColor),
              _kpiCard('نواقص معلقة', '${totalShortages - resolvedShortages}', _accentColor),
            ],
          ),
          pw.SizedBox(height: 24),

          // Status distribution
          if (byStatus.isNotEmpty) ...[
            _sectionHeader('📊 توزيع الإرساليات حسب الحالة'),
            pw.SizedBox(height: 12),
            _buildStatusDistributionTable(byStatus, total),
            pw.SizedBox(height: 24),
          ],

          // Daily activity
          if (byDay.isNotEmpty) ...[
            _sectionHeader('📈 النشاط اليومي (آخر 7 أيام)'),
            pw.SizedBox(height: 12),
            _buildDailyActivityTable(byDay),
            pw.SizedBox(height: 24),
          ],

          // Shortages by severity
          if (bySeverity.isNotEmpty) ...[
            _sectionHeader('⚠️ توزيع النواقص حسب الخطورة'),
            pw.SizedBox(height: 12),
            _buildSeverityTable(bySeverity, totalShortages),
            pw.SizedBox(height: 24),
          ],
        ],
      ),
    );

    // ═══ Page 3: Governorate Performance (if data available) ═══
    if (governorateData != null && governorateData.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          theme: pw.ThemeData.withFont(base: _font!, bold: _boldFont!),
          header: (ctx) => _buildHeader(title, dateStr),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _sectionHeader('🗺️ أداء المحافظات'),
            pw.SizedBox(height: 12),
            _buildGovernorateTable(governorateData),
            pw.SizedBox(height: 24),
          ],
        ),
      );
    }

    // ═══ Page 4: Shortages Details (if data available) ═══
    if (shortagesData != null && shortagesData.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          theme: pw.ThemeData.withFont(base: _font!, bold: _boldFont!),
          header: (ctx) => _buildHeader(title, dateStr),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _sectionHeader('📋 تفاصيل النواقص'),
            pw.SizedBox(height: 12),
            _buildShortagesTable(shortagesData),
          ],
        ),
      );
    }

    // Save
    final dir = await getTemporaryDirectory();
    final file = File(outputPath ??
        '${dir.path}/EPI_Report_${dateStr}_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════

  static pw.Widget _metaItem(String label, String value, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(value,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: _boldFont, fontSize: 16, color: _primaryColor)),
        pw.SizedBox(height: 4),
        pw.Text(label,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: font, fontSize: 10, color: _textMuted)),
      ],
    );
  }

  static pw.Widget _buildHeader(String title, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryColor, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('EPI Supervisor',
            style: pw.TextStyle(font: _boldFont, fontSize: 9, color: _primaryColor)),
          pw.Text(title,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: _font, fontSize: 9, color: _textMuted)),
          pw.Text(date,
            style: pw.TextStyle(font: _font, fontSize: 9, color: _textMuted)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('منصة مشرف EPI — تقرير سري',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: _lightFont, fontSize: 8, color: _textMuted)),
          pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: pw.TextStyle(font: _font, fontSize: 8, color: _textMuted)),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border(right: const pw.BorderSide(color: _primaryColor, width: 3)),
      ),
      child: pw.Text(title,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: _boldFont, fontSize: 14, color: _textDark)),
    );
  }

  static pw.Widget _kpiCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0)),
        boxShadow: [
          pw.BoxShadow(color: PdfColor.fromInt(0x0A000000), blurRadius: 4, offset: const PdfPoint(0, 2)),
        ],
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: 40, height: 40,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Text(value,
                style: pw.TextStyle(font: _boldFont, fontSize: 14, color: PdfColors.white)),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(label,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: _font, fontSize: 9, color: _textMuted)),
        ],
      ),
    );
  }

  static pw.Widget _buildStatusDistributionTable(Map<String, dynamic> byStatus, int total) {
    final statusLabels = {
      'approved': 'مقبول',
      'submitted': 'قيد المراجعة',
      'rejected': 'مرفوض',
      'draft': 'مسودة',
    };
    final statusColors = {
      'approved': _successColor,
      'submitted': _warningColor,
      'rejected': _accentColor,
      'draft': PdfColors.grey600,
    };

    final rows = <List<String>>[];
    final barWidgets = <pw.Widget>[];

    for (final entry in byStatus.entries) {
      final label = statusLabels[entry.key] ?? entry.key;
      final count = entry.value as int;
      final pct = total > 0 ? (count * 100 / total).toStringAsFixed(1) : '0.0';
      rows.add([label, '$count', '$pct%']);

      barWidgets.add(
        pw.Expanded(
          flex: count > 0 ? count : 1,
          child: pw.Container(
            height: 24,
            color: statusColors[entry.key] ?? PdfColors.grey400,
            child: pw.Center(
              child: pw.Text('$count',
                style: pw.TextStyle(font: _boldFont, fontSize: 9, color: PdfColors.white)),
            ),
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        // Table
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
          headerStyle: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _primaryColor),
          cellStyle: pw.TextStyle(font: _font, fontSize: 10),
          cellAlignment: pw.Alignment.centerRight,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          headers: ['الحالة', 'العدد', 'النسبة'],
          data: rows,
        ),
        pw.SizedBox(height: 12),
        // Visual bar
        pw.Container(
          height: 28,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
          ),
          clipBehavior: pw.Clip.hardEdge,
          child: pw.Row(children: barWidgets),
        ),
      ],
    );
  }

  static pw.Widget _buildDailyActivityTable(Map<String, dynamic> byDay) {
    final entries = byDay.entries.toList();
    final maxCount = entries.fold<int>(0, (max, e) => (e.value as int) > max ? (e.value as int) : max);

    final rows = entries.map((e) {
      final count = e.value as int;
      final barWidth = maxCount > 0 ? (count / maxCount * 100).toStringAsFixed(0) : '0';
      return [e.key, '$count', '$barWidth%'];
    }).toList();

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      headerStyle: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellStyle: pw.TextStyle(font: _font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      headers: ['اليوم', 'عدد الإرساليات', 'النسبة'],
      data: rows,
    );
  }

  static pw.Widget _buildSeverityTable(Map<String, dynamic> bySeverity, int total) {
    final severityLabels = {
      'critical': '🔴 حرج',
      'high': '🟠 عالي',
      'medium': '🟡 متوسط',
      'low': '🟢 منخفض',
    };

    final rows = <List<String>>[];
    for (final entry in bySeverity.entries) {
      final label = severityLabels[entry.key] ?? entry.key;
      final count = entry.value as int;
      final pct = total > 0 ? (count * 100 / total).toStringAsFixed(1) : '0.0';
      rows.add([label, '$count', '$pct%']);
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      headerStyle: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _accentColor),
      cellStyle: pw.TextStyle(font: _font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      headers: ['مستوى الخطورة', 'العدد', 'النسبة'],
      data: rows,
    );
  }

  static pw.Widget _buildGovernorateTable(List<Map<String, dynamic>> data) {
    final rows = data.take(30).map((gov) {
      final name = gov['name_ar'] as String? ?? '-';
      final subs = gov['submissions'] as Map<String, dynamic>? ?? {};
      final total = '${subs['total'] ?? 0}';
      final approved = '${subs['approved'] ?? 0}';
      final rate = '${subs['approval_rate'] ?? 0}%';
      return [name, total, approved, rate];
    }).toList();

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      headerStyle: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _primaryColor),
      cellStyle: pw.TextStyle(font: _font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      headers: ['المحافظة', 'الإجمالي', 'مقبول', 'نسبة القبول'],
      data: rows,
    );
  }

  static pw.Widget _buildShortagesTable(List<Map<String, dynamic>> data) {
    final severityLabels = {
      'critical': 'حرج',
      'high': 'عالي',
      'medium': 'متوسط',
      'low': 'منخفض',
    };

    final rows = data.take(50).map((s) {
      final item = s['item_name'] as String? ?? '-';
      final category = s['item_category'] as String? ?? '-';
      final severity = severityLabels[s['severity']] ?? s['severity'] ?? '-';
      final qty = '${s['quantity_needed'] ?? '-'}';
      final gov = (s['governorates'] as Map?)?['name_ar'] ?? '-';
      final resolved = s['is_resolved'] == true ? '✅' : '❌';
      return [item, category, severity, qty, gov, resolved];
    }).toList();

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      headerStyle: pw.TextStyle(font: _boldFont, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _warningColor),
      cellStyle: pw.TextStyle(font: _font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      headers: ['الصنف', 'الفئة', 'الخطورة', 'الكمية', 'المحافظة', 'الحالة'],
      data: rows,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FONT LOADING
  // ═══════════════════════════════════════════════════════════════════════

  static Future<void> _loadFonts() async {
    if (_font != null) return;
    try {
      final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _font = pw.Font.ttf(regularData);
      _boldFont = pw.Font.ttf(boldData);
      // Try light font
      try {
        final lightData = await rootBundle.load('assets/fonts/Cairo-Light.ttf');
        _lightFont = pw.Font.ttf(lightData);
      } catch (_) {
        _lightFont = _font; // Fallback to regular
      }
    } catch (e) {
      // Fallback: use built-in font
      _font = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
      _lightFont = pw.Font.helvetica();
    }
  }
}
