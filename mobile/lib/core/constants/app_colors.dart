import 'package:flutter/material.dart';

/// AppColors — Centralized design system color palette for SIKA
/// Strictly matching the official SIKA Design Spec board
class AppColors {
  // Brand Identity (Premium Indigo)
  static const Color brandPrimary = Color(0xFF4F46E5);
  static const Color brandSecondary = Color(0xFF38BDF8);
  static const Color brandAccent = Color(0xFF10B981); // Pour l'IA, le succès

  // Dark Mode Colors
  static const Color darkBackground =
      Color(0xFF020614); // Ultra deep blue/black
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceHighlight = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF1E293B);

  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF); // White
  static const Color lightSurfaceHighlight = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400

  // Semantic
  static const Color primary = brandPrimary;
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Aliases (Keeping old ones temporarily for backward compatibility)
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color border = darkBorder;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
  static const Color emerald = success;
  static const Color indigo = brandPrimary;
  static const Color cyan = brandSecondary;
  static const Color amber = warning;
  static const Color rose = error;
}
