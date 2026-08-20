import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

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
  final bool hasSeenOnboarding; // Si l'onboarding a déjà été vu sur cet appareil
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
  static const String _keyAccessToken = 'sika_access_token';

  final ApiService _apiService = ApiService();

  AuthNotifier() : super(AuthState(isAuthenticated: false, hasSeenOnboarding: false)) {
    _loadInitialPreferences();
  }

  /// Charge les préférences locales (Onboarding vu / Jeton OAuth2 sauvegardé)
  Future<void> _loadInitialPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_keyHasSeenOnboarding) ?? false;
      final savedToken = prefs.getString(_keyAccessToken);

      if (savedToken != null && savedToken.isNotEmpty) {
        try {
          final res = await _apiService.getMe(savedToken);
          final uData = res["user"] ?? {};
          // P0.3: le backend renvoie 'full_name', pas 'name'
          final displayName = (uData["full_name"] ?? uData["name"] ?? 'Utilisateur').toString();
          if (mounted) {
            state = state.copyWith(
              hasSeenOnboarding: true,
              isAuthenticated: true,
              accessToken: savedToken,
              user: UserProfileData(
                id: (uData["user_id"] ?? uData["id"] ?? 'usr_saved').toString(),
                name: displayName,
                email: (uData["sub"] ?? uData["email"] ?? 'utilisateur@sika.app').toString(),
              ),
            );
          }
        } catch (e) {
          // P0.2: si le jeton est expiré ou invalide, on déconnecte proprement
          // au lieu de maintenir une session fantome avec une fausse identité.
          debugPrint('[AUTH PREFS] Jeton sauvegardé invalid ou expiré, déconnexion: $e');
          await prefs.remove(_keyAccessToken);
          if (mounted) {
            state = state.copyWith(
              hasSeenOnboarding: true,
              isAuthenticated: false,
              accessToken: null,
              user: null,
            );
          }
        }
      } else {
        if (mounted) {
          state = state.copyWith(hasSeenOnboarding: hasSeen);
        }
      }
    } catch (e) {
      debugPrint('[AUTH PREFS] Erreur chargement préférences: $e');
    }
  }

  /// Marque l'onboarding comme terminé définitivement pour cet appareil
  Future<void> completeOnboarding() async {
    state = state.copyWith(hasSeenOnboarding: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
    } catch (e) {
      debugPrint('[AUTH PREFS] Erreur sauvegarde Onboarding: $e');
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
      // P0.3: le backend renvoie 'full_name'
      final displayName = (uData["full_name"] ?? uData["name"] ?? email.trim()).toString();

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? 'usr_1').toString(),
          name: displayName,
          email: (uData["email"] ?? email.trim()).toString(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      await prefs.setString(_keyAccessToken, token);
      return true;
    } catch (e) {
      debugPrint('[AUTH ERROR] Erreur login API: $e');
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
      // P0.3: le backend renvoie 'full_name'
      final displayName = (uData["full_name"] ?? uData["name"] ?? name.trim()).toString();

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? 'usr_1').toString(),
          name: displayName,
          email: (uData["email"] ?? email.trim()).toString(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      await prefs.setString(_keyAccessToken, token);
      return true;
    } catch (e) {
      debugPrint('[AUTH ERROR] Erreur register API: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Connexion et inscription instantanée via Google Sign-In (OAuth2)
  Future<bool> loginWithGoogle({String email = "david.yao@gmail.com", String name = "David YAO"}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _apiService.googleLogin(email: email, name: name);
      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      // P0.3: le backend renvoie 'full_name'
      final displayName = (uData["full_name"] ?? uData["name"] ?? name).toString();

      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData["id"] ?? 'usr_google_1').toString(),
          name: displayName,
          email: (uData["email"] ?? email).toString(),
          isGoogleAuth: true,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
      await prefs.setString(_keyAccessToken, token);
      return true;
    } catch (e) {
      debugPrint('[AUTH ERROR] Erreur Google login API: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Déconnexion sécurisée (Log Out)
  Future<void> logout() async {
    debugPrint('[AUTH] User logged out');
    try {
      await _apiService.logout();
    } catch (_) {}

    state = AuthState(
      isAuthenticated: false,
      hasSeenOnboarding: true, // Garde l'onboarding comme vu pour ne pas le ré-afficher !
      user: null,
      accessToken: null,
      isLoading: false,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
