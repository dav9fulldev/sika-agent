import 'package:flutter/foundation.dart';

/// Configuration centralisée de l'environnement SIKA.
///
/// Stratégie de résolution de l'URL de base (par priorité décroissante) :
///
///   1. --dart-define=SIKA_API_URL=https://... (override explicite au build time)
///   2. kReleaseMode → URL Cloud Run de production
///   3. Sinon (debug / profile) → Émulateur Android local ou IP réseau locale
///
/// Utilisation :
///   - Development : flutter run                       → backend local
///   - Production  : flutter build apk --release       → Cloud Run
///   - Override    : flutter build apk --release \
///                     --dart-define=SIKA_API_URL=https://...

class AppConfig {
  AppConfig._(); // Singleton statique — pas d'instanciation.

  /// Version affichée dans les réglages (mise à jour par release-please avec pubspec.yaml).
  static const String appVersion = '3.2.0'; // x-release-please-version

  // ---------------------------------------------------------------------------
  // URL Cloud Run de production (à mettre à jour après chaque déploiement)
  // ---------------------------------------------------------------------------

  /// URL HTTPS du backend SIKA sur Google Cloud Run.
  /// Remplacez cette valeur après votre premier `gcloud run deploy`.
  static const String _productionUrl =
      'https://sika-backend-1064195418653.europe-west9.run.app';

  // ---------------------------------------------------------------------------
  // URL de développement local
  // ---------------------------------------------------------------------------

  /// Émulateur Android : URL du cloud run
  static const String _emulatorUrl =
      'https://sika-backend-1064195418653.europe-west9.run.app';

  // ---------------------------------------------------------------------------
  // Résolution de l'URL effective
  // ---------------------------------------------------------------------------

  /// URL de l'API SIKA résolue à la compilation.
  ///
  /// Ordre de priorité :
  ///   1. `--dart-define=SIKA_API_URL=https://...` si fourni explicitement
  ///   2. `_productionUrl` en release
  ///   3. `_emulatorUrl` en debug / profile
  static const String _dartDefineUrl = String.fromEnvironment('SIKA_API_URL');

  /// ID client OAuth Google de type « Application Web » (public). Google l'utilise comme audience du jeton
  /// d'identité que le backend vérifie : sans lui, Android ne renvoie pas de jeton et la connexion Google échoue.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '1064195418653-coq6i7fnbgn5dvobbets8orh619s3d0s.apps.googleusercontent.com',
  );

  static String get baseUrl {
    // Priorité 1 : override explicite fourni au build
    if (_dartDefineUrl.isNotEmpty) return _dartDefineUrl;

    // Priorité 2 : release → Cloud Run
    if (kReleaseMode) return _productionUrl;

    // Priorité 3 : debug/profile → émulateur local
    return _emulatorUrl;
  }

  // ---------------------------------------------------------------------------
  // Timeouts HTTP (à appliquer sur toutes les requêtes)
  // ---------------------------------------------------------------------------

  /// Timeout standard pour les requêtes API (chat, wallet, auth).
  static const Duration defaultTimeout = Duration(seconds: 180);

  /// Timeout étendu pour les opérations agent IA (traitement LLM/TTS).
  static const Duration agentTimeout = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // Helpers de diagnostic
  // ---------------------------------------------------------------------------

  static bool get isProduction => kReleaseMode && _dartDefineUrl.isEmpty;

  static String get environmentName {
    if (_dartDefineUrl.isNotEmpty) return 'custom';
    if (kReleaseMode) return 'production';
    return 'development';
  }

  /// Vérifie que l'URL de production a été correctement configurée.
  /// Lance une assertion en debug si la valeur placeholder est encore présente.
  static void assertProductionUrlConfigured() {
    assert(
      !kReleaseMode || !baseUrl.contains('XXXX'),
      '\n\n'
      '⚠️  SIKA — URL Cloud Run non configurée !\n'
      'Ouvrez lib/core/config/app_config.dart et remplacez :\n'
      '  _productionUrl = "https://sika-backend-XXXX-ew.a.run.app"\n'
      'par votre vraie URL Cloud Run, ou utilisez :\n'
      '  flutter build apk --release --dart-define=SIKA_API_URL=https://...\n',
    );
  }
}
