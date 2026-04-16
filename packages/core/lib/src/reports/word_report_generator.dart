import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Generates Word-compatible HTML reports (.doc) with RTL Arabic support.
/// Uses HTML format which Word opens natively on all platforms.
class WordReportGenerator {
  /// Generate a Word-compatible document for a form's submissions.
  static Future<File> generate(
    Map<String, dynamic> form,
    List<Map<String, dynamic>> subs,
  ) async {
    final html = _buildHTML(form, subs);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${form['id']}.doc');
    await file.writeAsString(html, encoding: utf8);
    return file;
  }

  static String _buildHTML(
    Map<String, dynamic> form,
    List<Map<String, dynamic>> subs,
  ) {
    final title = form['title_ar'] ?? form['title'] ?? 'تقرير';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCount =
        subs.where((s) => (s['created_at'] ?? '').startsWith(today)).length;
    final submitted = subs.where((s) => s['status'] == 'submitted').length;
    final rejected = subs.where((s) => s['status'] == 'rejected').length;
    final completionRate = subs.isEmpty ? 0 : (submitted * 100 ~/ subs.length);

    return '''<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<style>
  body { font-family: Arial, Tahoma, sans-serif; direction: rtl; margin: 24px; }
  h1 { color: #1565C0; border-bottom: 3px solid #1565C0; padding-bottom: 8px; }
  h2 { color: #1976D2; margin-top: 24px; }
  .stats { display: flex; gap: 16px; margin: 16px 0; }
  .stat-box { border: 1px solid #90CAF9; border-radius: 8px; padding: 12px 20px; text-align: center; }
  .stat-value { font-size: 24px; font-weight: bold; color: #1565C0; }
  .stat-label { font-size: 12px; color: #666; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; margin-top: 12px; }
  th { background: #1565C0; color: white; padding: 10px; text-align: right; }
  td { border: 1px solid #ddd; padding: 8px; }
  tr:nth-child(even) { background: #E3F2FD; }
  .footer { margin-top: 32px; font-size: 11px; color: #999; text-align: center; }
</style>
</head>
<body>
<h1>$title</h1>
<p>تاريخ التقرير: $today</p>

<div class="stats">
  <div class="stat-box">
    <div class="stat-value">${subs.length}</div>
    <div class="stat-label">إجمالي الإرساليات</div>
  </div>
  <div class="stat-box">
    <div class="stat-value">$todayCount</div>
    <div class="stat-label">إرسالاليات اليوم</div>
  </div>
  <div class="stat-box">
    <div class="stat-value">$completionRate%</div>
    <div class="stat-label">نسبة الإنجاز</div>
  </div>
  <div class="stat-box">
    <div class="stat-value">$rejected</div>
    <div class="stat-label">مرفوضة</div>
  </div>
</div>

<h2>تفاصيل الإرساليات</h2>
<table>
  <tr>
    <th>م</th>
    <th>التاريخ</th>
    <th>الحالة</th>
    <th>الجهة</th>
  </tr>
${subs.take(200).map((s) {
      final date = (s['created_at'] ?? '').toString().length >= 10
          ? s['created_at'].toString().substring(0, 10)
          : '-';
      final status = s['status'] ?? '-';
      final facility = s['facility_name'] ?? '-';
      final idx = subs.indexOf(s) + 1;
      return '  <tr><td>$idx</td><td>$date</td><td>$status</td><td>$facility</td></tr>';
    }).join('\n')}
</table>

<div class="footer">تم إنشاء هذا التقرير تلقائياً بواسطة "EPI Supervisor's"</div>
</body>
</html>''';
  }
}
