import 'package:flutter/material.dart';

enum BtVisualStyle {
  gemini,
  claude,
}

class BtThemePalette {
  final Color bg;
  final Color sidebarBg;
  final Color surface;
  final Color card;
  final Color cardElevated;
  final Color border;
  final Color accent;
  final Color accentSecondary;
  final Color userBubble;
  final Color aiBubble;
  final Color codeBg;
  final Color codeHeaderBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final LinearGradient brandGradient;

  const BtThemePalette({
    required this.bg,
    required this.sidebarBg,
    required this.surface,
    required this.card,
    required this.cardElevated,
    required this.border,
    required this.accent,
    required this.accentSecondary,
    required this.userBubble,
    required this.aiBubble,
    required this.codeBg,
    required this.codeHeaderBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.brandGradient,
  });

  static const BtThemePalette gemini = BtThemePalette(
    bg: Color(0xFF0B0E17),
    sidebarBg: Color(0xFF080A11),
    surface: Color(0xFF131826),
    card: Color(0xFF171E30),
    cardElevated: Color(0xFF1E273D),
    border: Color(0xFF26314D),
    accent: Color(0xFF60A5FA),
    accentSecondary: Color(0xFFA855F7),
    userBubble: Color(0xFF1E293B),
    aiBubble: Color(0xFF121725),
    codeBg: Color(0xFF090C14),
    codeHeaderBg: Color(0xFF151C2E),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF4F8EF7),
        Color(0xFF8B5CF6),
        Color(0xFFEC4899),
      ],
    ),
  );

  static const BtThemePalette claude = BtThemePalette(
    bg: Color(0xFF171614),
    sidebarBg: Color(0xFF12110F),
    surface: Color(0xFF211F1C),
    card: Color(0xFF262320),
    cardElevated: Color(0xFF302C28),
    border: Color(0xFF3B3631),
    accent: Color(0xFFD97757),
    accentSecondary: Color(0xFFEAB308),
    userBubble: Color(0xFF2C2824),
    aiBubble: Color(0xFF1F1D1A),
    codeBg: Color(0xFF11100E),
    codeHeaderBg: Color(0xFF282521),
    textPrimary: Color(0xFFF5F2EB),
    textSecondary: Color(0xFFA8A29E),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFD97757),
        Color(0xFFE09F67),
        Color(0xFFC25E3E),
      ],
    ),
  );

  static BtThemePalette of(BtVisualStyle style) {
    return style == BtVisualStyle.claude ? claude : gemini;
  }
}

ThemeData buildBtChatTheme(BtVisualStyle style) {
  final p = BtThemePalette.of(style);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.dark(
      primary: p.accent,
      secondary: p.accentSecondary,
      surface: p.surface,
      error: p.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.sidebarBg,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: p.border,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.cardElevated,
      contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.textSecondary, fontSize: 13.5),
      labelStyle: TextStyle(color: p.textSecondary, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
  );
}
