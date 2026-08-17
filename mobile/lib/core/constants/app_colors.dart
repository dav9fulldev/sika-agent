import 'package:flutter/material.dart';

/// AppColors — Centralized design system color palette for SIKA
/// Strictly matching the official SIKA Design Spec board
class AppColors {
  // Brand Palette Accents
  static const Color indigo = Color(0xFF6366F1);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFEF4444);

  // Background & Surfaces
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceDarker = Color(0xFF0F172A);
  static const Color border = Color(0xFF334155);

  // Typography & Text
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDimmed = Color(0xFF475569);
  static const Color white = Colors.white;

  // Semantic Shortcuts
  static const Color primary = indigo;
  static const Color primaryLight = cyan;
  static const Color warning = amber;
  static const Color success = emerald;
  static const Color error = rose;
}
