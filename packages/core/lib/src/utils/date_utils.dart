import 'package:intl/intl.dart';

/// Date and time utility functions for the EPI platform.
class DateUtils {
  DateUtils._();

  static final DateFormat _arabicDate = DateFormat('dd MMMM yyyy', 'ar');
  static final DateFormat _arabicDateTime = DateFormat('dd/MM/yyyy hh:mm a', 'ar');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoDateTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeOnly = DateFormat('HH:mm');

  // ─── Formatters ───────────────────────────────────────────────────────────

  /// Format as Arabic long date: "١٠ أبريل ٢٠٢٥"
  static String formatArabic(DateTime date) {
    try {
      return _arabicDate.format(date);
    } catch (_) {
      return _shortDate.format(date);
    }
  }

  /// Format as Arabic date+time
  static String formatArabicDateTime(DateTime date) {
    try {
      return _arabicDateTime.format(date);
    } catch (_) {
      return _isoDateTime.format(date);
    }
  }

  /// Format as ISO date: "2025-04-10"
  static String toIsoDate(DateTime date) => _isoDate.format(date);

  /// Format as short date: "10/04/2025"
  static String toShortDate(DateTime date) => _shortDate.format(date);

  /// Format time only: "14:30"
  static String toTime(DateTime date) => _timeOnly.format(date);

  // ─── Relative Time ────────────────────────────────────────────────────────

  /// Returns human-readable relative time in Arabic
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
    if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
    return 'منذ ${(diff.inDays / 365).floor()} سنة';
  }

  // ─── Parsers ──────────────────────────────────────────────────────────────

  /// Parse ISO string safely
  static DateTime? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Parse ISO string with fallback
  static DateTime parseOrNow(String? value) {
    return tryParse(value) ?? DateTime.now();
  }

  // ─── Ranges ───────────────────────────────────────────────────────────────

  /// Get start of day (00:00:00)
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Get end of day (23:59:59)
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Get start of month
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  /// Get end of month
  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is within last N days
  static bool isWithinLastDays(DateTime date, int days) {
    return DateTime.now().difference(date).inDays <= days;
  }
}

extension DateTimeExtension on DateTime {
  String get arabicFormat => DateUtils.formatArabic(this);
  String get arabicDateTime => DateUtils.formatArabicDateTime(this);
  String get timeAgo => DateUtils.timeAgo(this);
  String get isoDate => DateUtils.toIsoDate(this);
  bool get isToday => DateUtils.isToday(this);
}
