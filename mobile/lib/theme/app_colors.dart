import 'package:flutter/material.dart';

/// Theme Controller managing dynamic Light/Dark mode transitions
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  ThemeMode _themeMode = ThemeMode.system; // Default:
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
  final Color surface2;
  final Color text;
  final Color muted;
  final Color teal; // Maps to Accent for full backwards compatibility
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color red;
  final Color critical;
  final Color amber;
  final Color warning;
  final Color green;
  final Color success;
  final Color info;
  final Color border;
  final Color navBorder;
  final Color cardBorder;
  final Color navBg;
  final Color inputBg;
  final Color logBg;
  final Color codeBg;
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
    required this.surface2,
    required this.text,
    required this.muted,
    required this.teal,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.red,
    required this.critical,
    required this.amber,
    required this.warning,
    required this.green,
    required this.success,
    required this.info,
    required this.border,
    required this.navBorder,
    required this.cardBorder,
    required this.navBg,
    required this.inputBg,
    required this.logBg,
    required this.codeBg,
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

  // Convenience aliases matching HTML CSS variables
  Color get cardSecondary => surface2;
  Color get ok => success;
  Color get cr => critical;
  Color get wn => warning;
  Color get inColor => info;
  Color get criticalSoft => badgeRedBg;
  Color get warningSoft => badgeAmberBg;
  Color get successSoft => badgeGreenBg;
  Color get infoSoft => badgeTealBg;
  Color get okSoft => badgeGreenBg;
  Color get crSoft => badgeRedBg;
  Color get wnSoft => badgeAmberBg;
}

/// Exact colors from the new HTML prototype specification (Group 33)
class AppColors {
  // -------------------------------------------------------------
  // 1. NEW LIGHT PALETTE (Group 33 Design System)
  // -------------------------------------------------------------
  static const AppColorScheme light = AppColorScheme(
    isDark: false,
    bg: Color(0xFFF4F5F9), // --bg: #F4F5F9
    card: Color(0xFFFFFFFF), // --sf: #FFFFFF
    cardAccent: Color(0xFFEEF0F5), // --sf2: #EEF0F5
    surface2: Color(0xFFEEF0F5),
    text: Color(0xFF151922), // --tx: #151922
    muted: Color(0xFF545D6E), // --mu: #545D6E
    teal: Color(0xFF5A43D6), // --ac: #5A43D6 (Deep Violet)
    accent: Color(0xFF5A43D6),
    onAccent: Color(0xFFFFFFFF), // --onac: #FFFFFF
    accentSoft: Color(0x1A5A43D6), // rgba(90,67,214,.10)
    red: Color(0xFFB42318), // --cr: #B42318
    critical: Color(0xFFB42318),
    amber: Color(0xFF8A5300), // --wn: #8A5300
    warning: Color(0xFF8A5300),
    green: Color(0xFF13703F), // --ok: #13703F
    success: Color(0xFF13703F),
    info: Color(0xFF1D58B8), // --in: #1D58B8
    border: Color(0xFFDCE0E8), // --ln: #DCE0E8
    navBorder: Color(0xFFDCE0E8),
    cardBorder: Color(0xFFDCE0E8),
    navBg: Color(0xFFFFFFFF),
    inputBg: Color(0xFFFFFFFF),
    logBg: Color(0xFFF1F2F7), // --code: #F1F2F7
    codeBg: Color(0xFFF1F2F7),
    badgeRedBg: Color(0x17B42318), // rgba(180,35,24,.09)
    badgeAmberBg: Color(0x1F8A5300), // rgba(196,128,0,.12)
    badgeGreenBg: Color(0x1A13703F), // rgba(19,112,63,.10)
    badgeTealBg: Color(0x1A5A43D6), // rgba(90,67,214,.10)
    noteBg: Color(0x1A5A43D6),
    noteText: Color(0xFF5A43D6),
    warnBg: Color(0x1F8A5300),
    warnText: Color(0xFF8A5300),
  );

  // -------------------------------------------------------------
  // 2. NEW DARK PALETTE (Group 33 Design System)
  // -------------------------------------------------------------
  static const AppColorScheme dark = AppColorScheme(
    isDark: true,
    bg: Color(0xFF0E1016), // --bg: #0E1016
    card: Color(0xFF161922), // --sf: #161922
    cardAccent: Color(0xFF1F2330), // --sf2: #1F2330
    surface2: Color(0xFF1F2330),
    text: Color(0xFFECEEF3), // --tx: #ECEEF3
    muted: Color(0xFFA4ACBC), // --mu: #A4ACBC
    teal: Color(0xFFA898FF), // --ac: #A898FF (Lavender)
    accent: Color(0xFFA898FF),
    onAccent: Color(0xFF140F2E), // --onac: #140F2E
    accentSoft: Color(0x29A898FF), // rgba(168,152,255,.16)
    red: Color(0xFFFF8080), // --cr: #FF8080
    critical: Color(0xFFFF8080),
    amber: Color(0xFFF5BB57), // --wn: #F5BB57
    warning: Color(0xFFF5BB57),
    green: Color(0xFF55D394), // --ok: #55D394
    success: Color(0xFF55D394),
    info: Color(0xFF7FB3FF), // --in: #7FB3FF
    border: Color(0xFF2B3040), // --ln: #2B3040
    navBorder: Color(0xFF2B3040),
    cardBorder: Color(0xFF2B3040),
    navBg: Color(0xFF161922),
    inputBg: Color(0xFF161922),
    logBg: Color(0xFF0A0C11), // --code: #0A0C11
    codeBg: Color(0xFF0A0C11),
    badgeRedBg: Color(0x24FF8080), // rgba(255,128,128,.14)
    badgeAmberBg: Color(0x24F5BB57), // rgba(245,187,87,.14)
    badgeGreenBg: Color(0x2155D394), // rgba(85,211,148,.13)
    badgeTealBg: Color(0x29A898FF), // rgba(168,152,255,.16)
    noteBg: Color(0x29A898FF),
    noteText: Color(0xFFA898FF),
    warnBg: Color(0x24F5BB57),
    warnText: Color(0xFFF5BB57),
  );

  // Dynamic getters based on active ThemeController state
  static AppColorScheme of([BuildContext? context]) {
    if (context != null) {
      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      return isDarkTheme ? dark : light;
    }
    return ThemeController.instance.isDark ? dark : light;
  }
}

extension AppThemeContextExtension on BuildContext {
  AppColorScheme get colors => AppColors.of(this);
}
