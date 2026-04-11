import 'package:flutter/material.dart';

/// EPI Supervisor Design System — Teal + Glassmorphism + RTL
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ─────────────────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF00897B);    // Teal 600
  static const Color primaryDark = Color(0xFF00695C);     // Teal 800
  static const Color primaryLight = Color(0xFF4DB6AC);    // Teal 300
  static const Color primarySurface = Color(0xFFE0F2F1);  // Teal 50

  static const Color secondaryColor = Color(0xFF5C6BC0);  // Indigo 400
  static const Color secondaryDark = Color(0xFF3949AB);   // Indigo 600
  static const Color secondaryLight = Color(0xFF9FA8DA);  // Indigo 200

  // ─── Semantic Colors ──────────────────────────────────────────────────────
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFB8C00);
  static const Color errorColor = Color(0xFFE53935);
  static const Color infoColor = Color(0xFF1E88E5);

  // ─── Severity Colors ──────────────────────────────────────────────────────
  static const Color criticalColor = Color(0xFFB71C1C);
  static const Color highColor = Color(0xFFE53935);
  static const Color mediumColor = Color(0xFFFB8C00);
  static const Color lowColor = Color(0xFF43A047);

  // ─── Neutral Colors ───────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color dividerColor = Color(0xFFF0F0F0);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF004D40)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFE0F2F1), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primaryColor.withOpacity(0.2),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Border Radius ────────────────────────────────────────────────────────
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMedium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLarge = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusCircle = BorderRadius.all(Radius.circular(1000));

  // ─── Glassmorphism ────────────────────────────────────────────────────────
  static BoxDecoration get glassmorphism => BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: radiusLarge,
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      );

  static BoxDecoration get glassmorphismDark => BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: radiusLarge,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      );

  // ─── Text Styles ──────────────────────────────────────────────────────────
  static const String fontPrimary = 'Cairo';
  static const String fontSecondary = 'Tajawal';

  static const TextStyle headingXL = TextStyle(
    fontFamily: fontPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle headingL = TextStyle(
    fontFamily: fontPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle headingM = TextStyle(
    fontFamily: fontPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyL = TextStyle(
    fontFamily: fontSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyM = TextStyle(
    fontFamily: fontSecondary,
    fontSize: 14,
    color: textPrimary,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: fontSecondary,
    fontSize: 12,
    color: textSecondary,
  );

  static const TextStyle labelM = TextStyle(
    fontFamily: fontSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontSecondary,
    fontSize: 11,
    color: textHint,
  );

  // ─── Theme Data ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceLight,
      ),
      fontFamily: fontSecondary,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          textStyle: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        border: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: labelM,
        hintStyle: const TextStyle(fontFamily: fontSecondary, color: textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: radiusSmall),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: fontSecondary, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontFamily: fontSecondary, fontSize: 11),
      ),
    );
  }

  // ─── Severity Helper ──────────────────────────────────────────────────────
  static Color severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return criticalColor;
      case 'high':
        return highColor;
      case 'medium':
        return mediumColor;
      case 'low':
        return lowColor;
      default:
        return textSecondary;
    }
  }

  // ─── Status Color ─────────────────────────────────────────────────────────
  static Color statusColor(String? status) {
    switch (status) {
      case 'approved':
        return successColor;
      case 'rejected':
        return errorColor;
      case 'submitted':
        return infoColor;
      case 'reviewed':
        return warningColor;
      case 'draft':
        return textSecondary;
      default:
        return textSecondary;
    }
  }
}
