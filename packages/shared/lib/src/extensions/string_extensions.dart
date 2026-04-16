/// String extension methods for the EPI Supervisor platform.
extension StringExtensions on String {
  // ─── Email ────────────────────────────────────────────────────────────────
  bool get isValidEmail =>
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
          .hasMatch(this);

  // ─── Phone (Yemeni) ───────────────────────────────────────────────────────
  bool get isValidYemeniPhone => RegExp(r'^(07[0-9]{8})$').hasMatch(this);

  /// Generic phone validator (7-15 digits)
  bool get isValidPhone => RegExp(r'^\+?[0-9]{7,15}$').hasMatch(this);

  // ─── General ──────────────────────────────────────────────────────────────
  bool get isNotBlank => trim().isNotEmpty;
  bool get isBlank => trim().isEmpty;

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get initials {
    final words = trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0].isNotEmpty ? words[0][0] : '';
    return '${words[0][0]}${words[words.length - 1][0]}';
  }

  // ─── Truncation ───────────────────────────────────────────────────────────
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  // ─── Numeric ──────────────────────────────────────────────────────────────
  int? toIntOrNull() => int.tryParse(this);
  double? toDoubleOrNull() => double.tryParse(this);
  bool get isNumeric => double.tryParse(this) != null;
}

/// Nullable string extensions
extension NullableStringExtensions on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
  String get orEmpty => this ?? '';
  String orDefault(String defaultValue) => isNullOrBlank ? defaultValue : this!;
}
