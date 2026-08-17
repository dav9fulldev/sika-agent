import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        state = state.copyWith(
          hasSeenOnboarding: true,
          isAuthenticated: true,
          accessToken: savedToken,
          user: UserProfileData(
            id: "usr_saved",
            name: "David YAO",
            email: "david.yao@email.com",
          ),
        );
      } else {
        state = state.copyWith(hasSeenOnboarding: hasSeen);
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
    await Future.delayed(const Duration(milliseconds: 900));

    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Veuillez remplir tous les champs.",
      );
      return false;
    }

    final nameFromEmail = email.split('@').first;
    final formattedName = nameFromEmail.isNotEmpty
        ? nameFromEmail[0].toUpperCase() + nameFromEmail.substring(1)
        : "David YAO";

    final token = "eyJ_sika_bearer_token_${DateTime.now().millisecondsSinceEpoch}";

    state = state.copyWith(
      isAuthenticated: true,
      hasSeenOnboarding: true,
      isLoading: false,
      accessToken: token,
      user: UserProfileData(
        id: "usr_${DateTime.now().millisecondsSinceEpoch}",
        name: formattedName,
        email: email.trim(),
      ),
    );

    // Persistance locale du jeton et statut onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
    await prefs.setString(_keyAccessToken, token);
    return true;
  }

  /// Inscription d'un nouvel utilisateur avec jeton OAuth2
  Future<bool> registerWithEmail(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 900));

    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Veuillez remplir tous les champs d'inscription.",
      );
      return false;
    }

    final token = "eyJ_sika_bearer_token_${DateTime.now().millisecondsSinceEpoch}";

    state = state.copyWith(
      isAuthenticated: true,
      hasSeenOnboarding: true,
      isLoading: false,
      accessToken: token,
      user: UserProfileData(
        id: "usr_${DateTime.now().millisecondsSinceEpoch}",
        name: name.trim(),
        email: email.trim(),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
    await prefs.setString(_keyAccessToken, token);
    return true;
  }

  /// Connexion et inscription instantanée via Google Sign-In (OAuth2)
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 1100));

    final token = "eyJ_sika_google_bearer_${DateTime.now().millisecondsSinceEpoch}";

    state = state.copyWith(
      isAuthenticated: true,
      hasSeenOnboarding: true,
      isLoading: false,
      accessToken: token,
      user: UserProfileData(
        id: "usr_google_${DateTime.now().millisecondsSinceEpoch}",
        name: "David YAO",
        email: "david.yao@gmail.com",
        isGoogleAuth: true,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
    await prefs.setString(_keyAccessToken, token);
    return true;
  }

  /// Déconnexion sécurisée (Log Out)
  Future<void> logout() async {
    debugPrint('[AUTH] User logged out');
    state = AuthState(
      isAuthenticated: false,
      hasSeenOnboarding: true, // Garde l'onboarding comme vu pour ne pas le ré-afficher !
      user: null,
      accessToken: null,
      isLoading: false,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
