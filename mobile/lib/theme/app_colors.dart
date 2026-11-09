import 'package:flutter/material.dart';

/// Theme Controller managing dynamic Light/Dark mode transitions
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}

/// Color Palette Container holding either Light or Dark tokens
class AppColorScheme {
  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardAccent;
  final Color text;
  final Color muted;
  final Color teal;
  final Color red;
  final Color amber;
  final Color green;
  final Color border;
  final Color navBorder;
  final Color cardBorder;
  final Color navBg;
  final Color inputBg;
  final Color logBg;
  final Color badgeRedBg;
  final Color badgeAmberBg;
  final Color badgeGreenBg;
  final Color badgeTealBg;
  final Color noteBg;
  final Color noteText;
  final Color warnBg;
  final Color warnText;

  const AppColorScheme({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.cardAccent,
    required this.text,
    required this.muted,
    required this.teal,
    required this.red,
    required this.amber,
    required this.green,
    required this.border,
    required this.navBorder,
    required this.cardBorder,
    required this.navBg,
    required this.inputBg,
    required this.logBg,
    required this.badgeRedBg,
    required this.badgeAmberBg,
    required this.badgeGreenBg,
    required this.badgeTealBg,
    required this.noteBg,
    required this.noteText,
    required this.warnBg,
    required this.warnText,
  });

  Color get badgeAmberText => warnText;
  Color get badgeRedText => red;
  Color get badgeGreenText => green;
  Color get badgeTealText => teal;
}

/// Exact colors from the official 28-screen specifications (Light & Dark)
class AppColors {
  // -------------------------------------------------------------
  // 1. OFFICIAL LIGHT PALETTE (100% Preserved & Untouched)
  // -------------------------------------------------------------
  static const AppColorScheme light = AppColorScheme(
    isDark: false,
    bg: Color(0xFFF3F6FB), // --bg: #f3f6fb
    card: Color(0xFFFFFFFF), // --cd: #ffffff
    cardAccent: Color(0xFFEAF0F9), // --cd2: #eaf0f9
    text: Color(0xFF0F1B33), // --tx: #0f1b33
    muted: Color(0xFF5A6A88), // --mu: #5a6a88
    teal: Color(0xFF0891B2), // --te: #0891b2
    red: Color(0xFFDC2626), // --rd: #dc2626
    amber: Color(0xFFB45309), // --am: #b45309
    green: Color(0xFF059669), // --gn: #059669
    border: Color(0xFFC3CFE4), // --line: #c3cfe4
    navBorder: Color(0xFFD5DEEC),
    cardBorder: Color(0xFFE1E6EE),
    navBg: Color(0xFFFFFFFF),
    inputBg: Color(0xFFFFFFFF),
    logBg: Color(0xFFEEF2F9),
    badgeRedBg: Color(0xFFFDE2E2),
    badgeAmberBg: Color(0xFFFDEFC8),
    badgeGreenBg: Color(0xFFD5F5E6),
    badgeTealBg: Color(0xFFD9F2F8),
    noteBg: Color(0xFFD9F2F8),
    noteText: Color(0xFF0B4F61),
    warnBg: Color(0xFFFDEFC8),
    warnText: Color(0xFF7A4B00),
  );

  // -------------------------------------------------------------
  // 2. OFFICIAL DARK PALETTE (From official dark mode spec)
  // -------------------------------------------------------------
  static const AppColorScheme dark = AppColorScheme(
    isDark: true,
    bg: Color(0xFF0B1226), // --bg: #0b1226
    card: Color(0xFF131C36), // --cd: #131c36
    cardAccent: Color(0xFF1B2647), // --cd2: #1b2647
    text: Color(0xFFE8EEFC), // --tx: #e8eefc
    muted: Color(0xFF93A3C8), // --mu: #93a3c8
    teal: Color(0xFF22D3EE), // --te: #22d3ee
    red: Color(0xFFF87171), // --rd: #f87171
    amber: Color(0xFFFBBF24), // --am: #fbbf24
    green: Color(0xFF34D399), // --gn: #34d399
    border: Color(0xFF2B3A6B), // --border: #2b3a6b
    navBorder: Color(0xFF243158),
    cardBorder: Color(0xFF243158),
    navBg: Color(0xFF0E1730),
    inputBg: Color(0xFF0E1730),
    logBg: Color(0xFF0A1020),
    badgeRedBg: Color(0xFF4A1D27),
    badgeAmberBg: Color(0xFF4A3A14),
    badgeGreenBg: Color(0xFF12402F),
    badgeTealBg: Color(0xFF0E3C47),
    noteBg: Color(0xFF0E3C47),
    noteText: Color(0xFFBFF3FB),
    warnBg: Color(0xFF4A3A14),
    warnText: Color(0xFFFFE29A),
  );

  // Dynamic getters based on active ThemeController state
  static AppColorScheme of([BuildContext? context]) {
    if (context != null) {
      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      return isDarkTheme ? dark : light;
    }
    return ThemeController.instance.isDark ? dark : light;
  }

  // Backward-compatible static constants pointing to Light defaults
  static const Color bg = Color(0xFFF3F6FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAccent = Color(0xFFEAF0F9);
  static const Color text = Color(0xFF0F1B33);
  static const Color muted = Color(0xFF5A6A88);
  static const Color teal = Color(0xFF0891B2);
  static const Color red = Color(0xFFDC2626);
  static const Color amber = Color(0xFFB45309);
  static const Color green = Color(0xFF059669);
  static const Color border = Color(0xFFC3CFE4);
  static const Color navBorder = Color(0xFFD5DEEC);
  static const Color cardBorder = Color(0xFFE1E6EE);
  static const Color badgeRedBg = Color(0xFFFDE2E2);
  static const Color badgeAmberBg = Color(0xFFFDEFC8);
  static const Color badgeGreenBg = Color(0xFFD5F5E6);
  static const Color badgeTealBg = Color(0xFFD9F2F8);
  static const Color noteBg = Color(0xFFD9F2F8);
  static const Color noteText = Color(0xFF0B4F61);
}

extension AppThemeContextExtension on BuildContext {
  AppColorScheme get colors => AppColors.of(this);
}
