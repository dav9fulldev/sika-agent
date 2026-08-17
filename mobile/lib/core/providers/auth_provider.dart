import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final bool isLoading;
  final UserProfileData? user;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = true, // Logged in by default for testing
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserProfileData? user,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(
          AuthState(
            isAuthenticated: true,
            user: UserProfileData(
              id: "usr_1001",
              name: "David YAO",
              email: "david.yao@email.com",
            ),
          ),
        );

  /// Connexion classique avec Email et Mot de passe
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

    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      user: UserProfileData(
        id: "usr_${DateTime.now().millisecondsSinceEpoch}",
        name: formattedName,
        email: email.trim(),
      ),
    );
    return true;
  }

  /// Inscription d'un nouvel utilisateur
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

    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      user: UserProfileData(
        id: "usr_${DateTime.now().millisecondsSinceEpoch}",
        name: name.trim(),
        email: email.trim(),
      ),
    );
    return true;
  }

  /// Connexion et inscription instantanée via Google Sign-In
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 1100));

    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      user: UserProfileData(
        id: "usr_google_${DateTime.now().millisecondsSinceEpoch}",
        name: "David YAO",
        email: "david.yao@gmail.com",
        isGoogleAuth: true,
      ),
    );
    return true;
  }

  /// Déconnexion sécurisée (Log Out)
  void logout() {
    debugPrint('[AUTH] User logged out');
    state = AuthState(
      isAuthenticated: false,
      user: null,
      isLoading: false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
