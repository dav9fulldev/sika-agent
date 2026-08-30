import 'package:flutter/material.dart';

/// AppSpacing — Système d'espacements et de rayons basé sur une grille de 8px (Figma-first)
class AppSpacing {
  // ==========================================
  // 1. ESPACEMENTS (Paddings & Margins)
  // ==========================================
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0; // Standard screen padding
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double huge = 64.0;

  // ==========================================
  // 2. BORDER RADII (Rayons)
  // ==========================================
  static const double radiusXs = 8.0; // Petits tags, badges
  static const double radiusSm = 12.0; // Petites cartes, inputs
  static const double radiusMd = 16.0; // Boutons standard
  static const double radiusLg = 24.0; // Cartes principales SikaSurface
  static const double radiusXl = 32.0; // Bottom sheets top radii

  static final BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);

  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(radiusXl),
  );

  // ==========================================
  // 3. ELEVATIONS & SHADOWS
  // ==========================================
  /// Ombre subtile pour le Light Mode (donne un effet "Glow" ou élévation douce)
  static List<BoxShadow> get lightShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];

  /// Ombre pour les éléments flottants (Bottom Navigation, Float Buttons)
  static List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 32,
          spreadRadius: 0,
          offset: const Offset(0, 16),
        ),
      ];
}
