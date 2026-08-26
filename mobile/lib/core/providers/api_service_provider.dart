import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider d'ApiService partagé qui injecte automatiquement le JWT
/// depuis authProvider vers chaque instance d'ApiService et gère la déconnexion
/// automatique sur 401 Unauthorized.
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();

  // Callback centralisé sur HTTP 401 : déconnexion immédiate et sécurisée
  apiService.onUnauthorized = () {
    if (ref.read(authProvider).isAuthenticated) {
      debugPrint(
          '[AUTH 401] Réception HTTP 401 sur requête authentifiée — déconnexion automatique.');
      ref.read(authProvider.notifier).logout();
    }
  };

  // Écoute les changements de token d'authentification
  // et les synchronise vers l'instance ApiService partagée.
  ref.listen<AuthState>(authProvider, (previous, next) {
    final newToken = next.accessToken;
    final oldToken = previous?.accessToken;

    if (newToken != oldToken) {
      apiService.token = newToken;
    }
  });

  // Initialisation immédiate avec le token déjà présent
  final initialToken = ref.read(authProvider).accessToken;
  apiService.token = initialToken;

  return apiService;
});
