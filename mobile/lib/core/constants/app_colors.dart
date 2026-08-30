import 'package:flutter/material.dart';

/// AppColors — SIKA V2.0 Premium Design Tokens
/// Inspired by modern Fintech & Product Design (Figma-first)
class AppColors {
  // ==========================================
  // 1. BRAND IDENTITY
  // ==========================================
  static const Color brandPrimary = Color(0xFF4F46E5); // SIKA Indigo
  static const Color brandSecondary = Color(0xFF38BDF8); // SIKA Cyan
  static const Color brandAccent = Color(0xFF10B981); // Success/AI Accent

  // ==========================================
  // 2. SEMANTIC TOKENS (LIGHT MODE)
  // ==========================================
  // Backgrounds
  static const Color lightBackground = Color(0xFFF8FAFC); // Very cool, clean white/gray (Slate 50)
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white for cards
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF); // Floating cards
  
  // Brand variations
  static const Color lightPrimarySoft = Color(0xFFEEF2FF); // Indigo 50 (for tags, active states)
  static const Color lightSecondarySoft = Color(0xFFE0F2FE); // Sky 50

  // Text
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900 (High contrast)
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600 (Subtitles)
  static const Color lightTextTertiary = Color(0xFF94A3B8); // Slate 400 (Placeholders, disabled)

  // Borders
  static const Color lightBorderSubtle = Color(0xFFF1F5F9); // Slate 100 (Dividers)
  static const Color lightBorderStrong = Color(0xFFE2E8F0); // Slate 200 (Inputs)

  // ==========================================
  // 3. SEMANTIC TOKENS (DARK MODE)
  // ==========================================
  // Backgrounds
  static const Color darkBackground = Color(0xFF0B1121); // Very deep night blue
  static const Color splashBackground = Color(0xFF020817); // Very dark night blue for splash screen
  static const Color darkSurface = Color(0xFF151E32); // Slightly elevated from background
  static const Color darkSurfaceElevated = Color(0xFF1E293B); // Modals, overlays
  
  // Brand variations
  static const Color darkPrimarySoft = Color(0xFF312E81); // Indigo 900
  static const Color darkSecondarySoft = Color(0xFF0C4A6E); // Sky 900

  // Text
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50 (High contrast)
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 (Subtitles)
  static const Color darkTextTertiary = Color(0xFF64748B); // Slate 500 (Placeholders)

  // Borders
  static const Color darkBorderSubtle = Color(0xFF1E293B); // Slate 800 (Dividers)
  static const Color darkBorderStrong = Color(0xFF334155); // Slate 700 (Inputs)

  // ==========================================
  // 4. STATUS & FEEDBACK
  // ==========================================
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successSoft = Color(0xFFD1FAE5); // Light mode
  static const Color successSoftDark = Color(0xFF064E3B); // Dark mode
  
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningSoftDark = Color(0xFF78350F);

  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color errorSoftDark = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF3B82F6); // Blue 500

  // ==========================================
  // 5. ANALYTICS & CHARTS
  // ==========================================
  static const Color chartIndigo = Color(0xFF6366F1); // Indigo 500
  static const Color chartCyan = Color(0xFF06B6D4); // Cyan 500
  static const Color chartEmerald = Color(0xFF10B981); // Emerald 500
  static const Color chartAmber = Color(0xFFF59E0B); // Amber 500
  static const Color chartCoral = Color(0xFFF43F5E); // Rose 500
  static const Color chartPurple = Color(0xFFA855F7); // Purple 500

  // ==========================================
  // 6. BACKWARD COMPATIBILITY ALIASES
  // (Do not use in new components, kept for existing code that will be migrated)
  // ==========================================
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color border = darkBorderStrong;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextTertiary;
  static const Color primary = brandPrimary;
  static const Color emerald = success;
  static const Color indigo = brandPrimary;
  static const Color cyan = brandSecondary;
  static const Color amber = warning;
  static const Color rose = error;
  
  // Keep the old surface highlights for components not yet migrated
  static const Color darkSurfaceHighlight = Color(0xFF1E293B);
  static const Color lightSurfaceHighlight = Color(0xFFF1F5F9);
  static const Color lightBorder = lightBorderStrong;
  static const Color darkBorder = darkBorderStrong;
  static const Color lightTextMuted = lightTextTertiary;
  static const Color darkTextMuted = darkTextTertiary;
}
