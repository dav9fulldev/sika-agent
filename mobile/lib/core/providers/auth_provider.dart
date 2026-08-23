import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

import 'package:google_sign_in/google_sign_in.dart';

class UserProfileData {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isPremium;
  final bool isGoogleAuth;

  UserProfileData({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isPremium = true,
    this.isGoogleAuth = false,
  });
}

class AuthState {
  final bool isAuthenticated;
  final bool hasSeenOnboarding;
  final bool isLoading;
  final String? accessToken;
  final UserProfileData? user;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.hasSeenOnboarding = false,
    this.isLoading = false,
    this.accessToken,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? hasSeenOnboarding,
    bool? isLoading,
    String? accessToken,
    UserProfileData? user,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isLoading: isLoading ?? this.isLoading,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const String _keyHasSeenOnboarding = 'sika_has_seen_onboarding';

  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthNotifier() : super(AuthState(isAuthenticated: false, hasSeenOnboarding: false)) {
    _loadInitialPreferences();
  }

  /// Charge les préférences et vérifie la session sécurisée
  Future<void> _loadInitialPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_keyHasSeenOnboarding) ?? false;
      final token = await _secureStorage.getAccessToken();

      if (token != null && token.isNotEmpty) {
        try {
          final res = await _apiService.getMe(token);
          final uData = res["user"] as Map<String, dynamic>;
          final displayName = (uData["full_name"] ?? uData["name"] ?? "Utilisateur SIKA").toString();

          if (mounted) {
            state = state.copyWith(
              hasSeenOnboarding: hasSeen,
              isAuthenticated: true,
              accessToken: token,
              user: UserProfileData(
                id: (uData["id"] ?? '1').toString(),
                name: displayName,
                email: (uData["email"] ?? "").toString(),
              ),
            );
            return;
          }
        } catch (_) {
          await _secureStorage.clearAll();
        }
      }

      if (mounted) {
        state = state.copyWith(
          hasSeenOnboarding: hasSeen,
          isAuthenticated: false,
          accessToken: null,
          user: null,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH PREFS] Erreur chargement initial: $e');
      }
    }
  }

  /// Marque l'onboarding comme terminé
  Future<void> completeOnboarding() async {
    state = state.copyWith(hasSeenOnboarding: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH PREFS] Erreur sauvegarde Onboarding: $e');
      }
    }
  }

  /// Connexion OAuth2 avec génération de jeton Bearer JWT
  Future<bool> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Veuillez remplir tous les champs.",
      );
      return false;
    }

    try {
      final res = await _apiService.login(email.trim(), password.trim());
      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      final displayName = (uData["full_name"] ?? uData["name"] ?? email.trim()).toString();

      await _secureStorage.saveAccessToken(token);

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? '1').toString(),
          name: displayName,
          email: (uData["email"] ?? email.trim()).toString(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur login API: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Inscription d'un nouvel utilisateur avec jeton OAuth2
  Future<bool> registerWithEmail(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Veuillez remplir tous les champs d'inscription.",
      );
      return false;
    }

    try {
      final res = await _apiService.register(name.trim(), email.trim(), password.trim());
      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      final displayName = (uData["full_name"] ?? uData["name"] ?? name.trim()).toString();

      await _secureStorage.saveAccessToken(token);

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? '1').toString(),
          name: displayName,
          email: (uData["email"] ?? email.trim()).toString(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur register API: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Connexion et inscription via Google Sign-In (OAuth2 / OIDC)
  Future<bool> loginWithGoogle({String? customEmail, String? customName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      String? email;
      String? name;
      String? photoUrl;
      String? idToken;

      if (customEmail != null && customEmail.trim().isNotEmpty) {
        email = customEmail.trim().toLowerCase();
        name = customName?.trim() ?? email.split('@').first;
      } else {
        final GoogleSignInAccount? account = await _googleSignIn.signIn();

        if (account == null) {
          state = state.copyWith(isLoading: false);
          return false;
        }

        final GoogleSignInAuthentication auth = await account.authentication;
        idToken = auth.idToken;
        email = account.email;
        name = account.displayName ?? email.split('@').first;
        photoUrl = account.photoUrl;
      }

      final res = await _apiService.googleLogin(
        idToken: idToken,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );

      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      final displayName = (uData["full_name"] ?? uData["name"] ?? name).toString();

      await _secureStorage.saveAccessToken(token);

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? '1').toString(),
          name: displayName,
          email: (uData["email"] ?? email).toString(),
          photoUrl: photoUrl,
          isGoogleAuth: true,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur Google Sign-In: $e');
      }
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
        msg = "Émulateur Android : Clé SHA-1 non configurée sur Google Cloud. Utilisez l'inscription classique par email.";
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  /// Déconnexion sécurisée (Log Out)
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {}

    await _secureStorage.clearAll();

    state = AuthState(
      isAuthenticated: false,
      hasSeenOnboarding: true,
      user: null,
      accessToken: null,
      isLoading: false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
