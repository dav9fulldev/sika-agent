import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SecureStorageService — Stockage sécurisé des jetons et informations sensibles
/// (Android Keystore / iOS Keychain) avec migration automatique depuis SharedPreferences.
class SecureStorageService {
  static const String _keyAccessToken = 'sika_auth_access_token';
  static const String _keyUserId = 'sika_auth_user_id';
  static const String _keyUserData = 'sika_auth_user_data';

  final FlutterSecureStorage _secureStorage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _secureStorage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  /// Récupère le jeton JWT avec migration transparente depuis SharedPreferences si nécessaire.
  Future<String?> getAccessToken() async {
    try {
      // 1. Recherche prioritaire dans le Secure Storage
      String? token = await _secureStorage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) {
        return token;
      }

      // 2. Migration depuis SharedPreferences (Legacy)
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString('auth_token') ??
          prefs.getString('jwt_token') ??
          prefs.getString(_keyAccessToken);

      if (legacyToken != null && legacyToken.isNotEmpty) {
        // Enregistrer dans le stockage sécurisé
        await _secureStorage.write(key: _keyAccessToken, value: legacyToken);
        // Supprimer l'ancienne copie non chiffrée
        await prefs.remove('auth_token');
        await prefs.remove('jwt_token');
        await prefs.remove(_keyAccessToken);
        return legacyToken;
      }

      return null;
    } catch (_) {
      // Fallback gracieux en cas d'indisponibilité temporaire du Keystore
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    }
  }

  /// Sauvegarde le jeton JWT dans le Secure Storage et nettoie les anciens emplacements non chiffrés.
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: _keyAccessToken, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('jwt_token');
      await prefs.remove(_keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
  }

  /// Supprime tous les jetons et sessions sécurisées (lors du logout).
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('jwt_token');
      await prefs.remove('sika_access_token');
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserData);
    } catch (_) {}
  }
}
