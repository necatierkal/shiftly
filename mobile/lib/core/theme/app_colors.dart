import 'package:flutter/material.dart';

class AppColors {
  // Brand colors (from prompt spec)
  static const Color primary = Color(0xFF3157D5);
  static const Color primaryLight = Color(0xFF5374E7);
  static const Color primaryDark = Color(0xFF1E3BB0);

  static const Color secondary = Color(0xFF19B394);
  static const Color accent = Color(0xFFF59E0B);

  // Backgrounds & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Backgrounds & Surfaces (Dark - Material 3 Deep Navy / Grey)
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color cardDark = Color(0xFF1F2937);
  static const Color borderDark = Color(0xFF374151);

  // Texts
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Shift Status Colors (Specification compliant)
  static const Color shiftDay = Color(0xFF3157D5);       // Gündüz: Mavi
  static const Color shiftNight = Color(0xFF7C3AED);     // Gece: Mor
  static const Color shiftOff = Color(0xFF10B981);       // İzin: Yeşil
  static const Color shiftSick = Color(0xFFF59E0B);      // Rapor/Tatil: Turuncu
  static const Color shiftEmpty = Color(0xFF9CA3AF);     // Boş/Diğer: Gri

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
