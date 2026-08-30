import 'package:flutter/material.dart';

/// AppTypography — Système typographique centralisé
class AppTypography {
  // Utilisation de la TextStyle de base, la police GoogleFonts (Outfit) 
  // est appliquée au niveau de app_theme.dart.
  // Ce fichier sert à définir les tailles, les graisses et les hauteurs de ligne.

  /// **Display** : Montants, Solde total
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.1,
  );

  /// **H1** : Titres de grands écrans
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// **H2** : Titres de sections (ex: "Vos transactions")
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// **H3** : Titres de sous-sections ou cartes
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  /// **Body Large** : Texte principal, actions, gros boutons
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// **Body Medium** : Texte par défaut, sous-titres, champs
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// **Body Medium Strong** : Variante en gras du bodyMedium
  static const TextStyle bodyMediumStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// **Caption** : Petits textes, labels, mentions légales
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
}
