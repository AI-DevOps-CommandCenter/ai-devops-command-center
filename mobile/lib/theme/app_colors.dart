import 'package:flutter/material.dart';

/// Exact colors from the official 28-screen specification (:root CSS)
class AppColors {
  // Backgrounds & Surfaces
  static const Color bg = Color(0xFFF3F6FB); // --bg: #f3f6fb (App Canvas)
  static const Color card = Color(0xFFFFFFFF); // --cd: #ffffff (Pure White Card)
  static const Color cardAccent = Color(0xFFEAF0F9); // --cd2: #eaf0f9 (Button / Secondary)
  
  // Typography
  static const Color text = Color(0xFF0F1B33); // --tx: #0f1b33 (Primary Navy Charcoal)
  static const Color muted = Color(0xFF5A6A88); // --mu: #5a6a88 (Muted Slate)
  
  // Brand & Functional Accents
  static const Color teal = Color(0xFF0891B2); // --te: #0891b2 (Primary Accent Cyan/Teal)
  static const Color red = Color(0xFFDC2626); // --rd: #dc2626 (Critical Alert)
  static const Color amber = Color(0xFFB45309); // --am: #b45309 (Warning)
  static const Color green = Color(0xFF059669); // --gn: #059669 (Healthy / Resolved)
  
  // Borders & Dividers
  static const Color border = Color(0xFFC3CFE4); // --line: #c3cfe4
  static const Color navBorder = Color(0xFFD5DEEC); // Navigation border
  static const Color cardBorder = Color(0xFFE1E6EE); // Subtle card outline
  
  // Pill / Badge Backgrounds
  static const Color badgeRedBg = Color(0xFFFDE2E2);
  static const Color badgeAmberBg = Color(0xFFFDEFC8);
  static const Color badgeGreenBg = Color(0xFFD5F5E6);
  static const Color badgeTealBg = Color(0xFFD9F2F8);
  static const Color noteBg = Color(0xFFD9F2F8);
  static const Color noteText = Color(0xFF0B4F61);
}
