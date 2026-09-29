import 'package:flutter/material.dart';

class SepiaTheme {
  // Academic Sepia Color Palette
  static const Color background = Color(0xFFFBF9F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF5EFE6);
  static const Color border = Color(0xFFE5DDD0);
  static const Color borderStrong = Color(0xFFD4C8B8);

  static const Color textPrimary = Color(0xFF2C2723);
  static const Color textSecondary = Color(0xFF6B6258);
  static const Color textMuted = Color(0xFF968B7E);

  static const Color primary = Color(0xFF6E4D25);
  static const Color primaryLight = Color(0xFFEFE6D8);
  static const Color accent = Color(0xFFA0522D);

  // Intent Tag Colors
  static const Color tagContextBg = Color(0xFFFFF3E0);
  static const Color tagContextText = Color(0xFFB75500);

  static const Color tagCompactionBg = Color(0xFFE8F5E9);
  static const Color tagCompactionText = Color(0xFF2E7D32);

  static const Color tagVectorBg = Color(0xFFE3F2FD);
  static const Color tagVectorText = Color(0xFF1565C0);

  static const Color tagPermissionBg = Color(0xFFF3E5F5);
  static const Color tagPermissionText = Color(0xFF7B1FA2);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.light(
        surface: surface,
        primary: primary,
        secondary: accent,
        onSurface: textPrimary,
      ),
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: border,
    );
  }
}
