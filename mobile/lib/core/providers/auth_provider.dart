import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/push_notifications.dart';
import '../services/secure_storage_service.dart';
import '../utils/network_error.dart';

import 'package:google_sign_in/google_sign_in.dart';

class UserProfileData {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final bool isPremium;
  final bool isGoogleAuth;
  final bool isKycVerified;
  /// Code pays ISO (ex. CI, US) ou nom saisi.
  final String? country;
  /// Champs que le serveur considère manquants (ex. full_name, country).
  final List<String> missingFields;
  /// none | submitted (en attente) | paypal (vérifié par PayPal)
  final String kycStatus;
  final bool paypalLinked;

  UserProfileData({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.isPremium = true,
    this.isGoogleAuth = false,
    this.isKycVerified = false,
    this.country,
    this.missingFields = const [],
    this.kycStatus = 'none',
    this.paypalLinked = false,
  });

  UserProfileData copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isPremium,
    bool? isGoogleAuth,
    bool? isKycVerified,
    String? country,
    List<String>? missingFields,
    String? kycStatus,
    bool? paypalLinked,
  }) {
    return UserProfileData(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      isGoogleAuth: isGoogleAuth ?? this.isGoogleAuth,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      country: country ?? this.country,
      missingFields: missingFields ?? this.missingFields,
      kycStatus: kycStatus ?? this.kycStatus,
      paypalLinked: paypalLinked ?? this.paypalLinked,
    );
  }
}

class AuthState {
  final bool isAuthenticated;
  final bool hasSeenOnboarding;
  final bool isLoading;
  final String? accessToken;
  final UserProfileData? user;
  final String? errorMessage;
  /// Code d'erreur du serveur (ex. USE_PAYPAL_SIGN_IN) pour afficher le message dans la langue de l'app.
  final String? errorCode;
  /// Vrai tant que la session enregistrée n'a pas été vérifiée au lancement.
  final bool isRestoring;
  /// Vrai si la session vient du stockage sécurisé (et non d'une connexion saisie) :
  /// l'application demande alors l'empreinte avant d'afficher les données.
  final bool restoredSession;

  AuthState({
    this.isAuthenticated = false,
    this.hasSeenOnboarding = false,
    this.isLoading = false,
    this.accessToken,
    this.user,
    this.errorMessage,
    this.errorCode,
    this.isRestoring = false,
    this.restoredSession = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? hasSeenOnboarding,
    bool? isLoading,
    String? accessToken,
    UserProfileData? user,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    bool? isRestoring,
    bool? restoredSession,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isLoading: isLoading ?? this.isLoading,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
      errorMessage: clearError ? errorMessage : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? errorCode : (errorCode ?? this.errorCode),
      isRestoring: isRestoring ?? this.isRestoring,
      restoredSession: restoredSession ?? this.restoredSession,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const String _keyHasSeenOnboarding = 'sika_has_seen_onboarding';

  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.googleServerClientId,
  );

  /// Applique l'état du profil renvoyé par le serveur (champs manquants, statut KYC).
  void _applyProfile(Map<String, dynamic> res) {
    final userMap = res['user'] is Map ? Map<String, dynamic>.from(res['user'] as Map) : <String, dynamic>{};
    final profile = res['profile'] ?? userMap['profile'];
    if (state.user == null || profile is! Map) return;
    state = state.copyWith(
      user: state.user!.copyWith(
        country: userMap['country']?.toString(),
        missingFields: List<String>.from(profile['missing_fields'] as List? ?? const []),
        kycStatus: profile['kyc_status']?.toString() ?? 'none',
        isKycVerified: profile['kyc_verified'] == true,
        paypalLinked: profile['paypal_linked'] == true,
      ),
    );
  }

  Completer<Uri>? _paypalRedirect;
  StreamSubscription<Uri>? _paypalLinkSub;

  /// Connexion avec PayPal : autorisation sur la page officielle PayPal (sandbox), retour par
  /// `sikapay://paypal/login`, puis échange du code par le serveur.
  Future<bool> loginWithPayPal() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final start = await _apiService.paypalLoginStart();
      final waiter = Completer<Uri>();
      _paypalRedirect = waiter;
      await _paypalLinkSub?.cancel();
      _paypalLinkSub = AppLinks().uriLinkStream.listen((uri) {
        if (uri.scheme == 'sikapay' && uri.host == 'paypal' && uri.path == '/login' && !waiter.isCompleted) {
          waiter.complete(uri);
        }
      });
      final launched = await launchUrl(Uri.parse(start['authorize_url'].toString()), mode: LaunchMode.externalApplication);
      if (!launched) {
        state = state.copyWith(isLoading: false, clearError: true, errorCode: 'PAYPAL_OPEN_FAILED', errorMessage: '');
        return false;
      }

      final uri = await waiter.future.timeout(const Duration(minutes: 5));
      if (uri.queryParameters['error'] != null || uri.queryParameters['code'] == null) {
        state = state.copyWith(isLoading: false, clearError: true, errorCode: 'PAYPAL_SIGN_IN_CANCELLED', errorMessage: '');
        return false;
      }
      final res = await _apiService.paypalLoginComplete(uri.queryParameters['code']!, uri.queryParameters['state'] ?? '');
      final token = res['access_token'] as String;
      final uData = Map<String, dynamic>.from(res['user'] as Map);
      await _secureStorage.saveAccessToken(token);
      state = state.copyWith(
        isAuthenticated: true,
        hasSeenOnboarding: true,
        isLoading: false,
        accessToken: token,
        user: UserProfileData(
          id: (uData['id'] ?? '').toString(),
          name: (uData['full_name'] ?? '').toString(),
          email: (uData['email'] ?? '').toString(),
          phone: uData['phone']?.toString(),
        ),
      );
      _applyProfile(res);
      await _rememberSignInMethod('paypal');
      return true;
    } on TimeoutException {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'PAYPAL_SIGN_IN_TIMEOUT', errorMessage: '');
      return false;
    } catch (e) {
      _fail(e, fallbackCode: 'PAYPAL_SIGN_IN_FAILED');
      return false;
    } finally {
      _paypalRedirect = null;
      await _paypalLinkSub?.cancel();
      _paypalLinkSub = null;
    }
  }

  /// L'utilisateur est revenu sans terminer la connexion PayPal.
  void cancelPayPalLogin() {
    final waiter = _paypalRedirect;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(Uri.parse('sikapay://paypal/login?error=cancelled'));
    }
  }

  /// Met à jour le profil (nom, pays) et l'état renvoyé par le serveur.
  Future<void> updateProfile({required String name, String? country}) async {
    final res = await _authedApi.updateUserInfo(name, state.user?.phone ?? '', country: country);
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(name: name, country: country));
    }
    _applyProfile(res);
  }

  static const String keyLastSignInMethod = 'sika_last_sign_in_method';

  /// Dernier moyen de connexion utilisé (email, google, paypal), rappelé sur l'écran Bienvenue.
  Future<void> _rememberSignInMethod(String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLastSignInMethod, method);
    } catch (_) {}
  }

  /// Client API porteur du jeton de la session courante (requis par les routes protégées).
  ApiService get _authedApi => _apiService..token = state.accessToken;

  AuthNotifier()
      : super(AuthState(isAuthenticated: false, hasSeenOnboarding: false, isRestoring: true)) {
    _loadInitialPreferences();
  }

  /// État fixé, sans restauration de session (tests d'écrans).
  @visibleForTesting
  AuthNotifier.withState(super.initial);

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
          final displayName =
              (uData["full_name"] ?? uData["name"] ?? "Utilisateur SIKA")
                  .toString();

          if (mounted) {
            state = state.copyWith(
              hasSeenOnboarding: hasSeen,
              isAuthenticated: true,
              isRestoring: false,
              restoredSession: true,
              accessToken: token,
              user: UserProfileData(
                id: (uData["id"] ?? '1').toString(),
                name: displayName,
                email: (uData["email"] ?? "").toString(),
                phone: uData["phone"]?.toString(),
                isKycVerified: uData["is_kyc_verified"] == 1 ||
                    uData["is_kyc_verified"] == true,
              ),
            );
            _applyProfile(Map<String, dynamic>.from(res));
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
          isRestoring: false,
          accessToken: null,
          user: null,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH PREFS] Erreur chargement initial: $e');
      }
      if (mounted) state = state.copyWith(isRestoring: false);
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
    state = state.copyWith(isLoading: true, clearError: true);

    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'FIELDS_REQUIRED', errorMessage: '');
      return false;
    }

    try {
      final res = await _apiService.login(email.trim(), password.trim());
      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      final displayName =
          (uData["full_name"] ?? uData["name"] ?? email.trim()).toString();

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
          phone: uData["phone"]?.toString(),
          isKycVerified:
              uData["is_kyc_verified"] == 1 || uData["is_kyc_verified"] == true,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);

      // Sync context with native side
      _applyProfile(Map<String, dynamic>.from(res));
      await _rememberSignInMethod('email');

      return true;
    } on AuthApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message, errorCode: e.code);
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur login API: $e');
      }

      _fail(e);
      return false;
    }
  }

  /// Inscription d'un nouvel utilisateur avec jeton OAuth2
  Future<bool> registerWithEmail(
      String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'FIELDS_REQUIRED', errorMessage: '');
      return false;
    }

    try {
      final res = await _apiService.register(
          name.trim(), email.trim(), password.trim());
      final token = res["access_token"] as String;
      final uData = res["user"] as Map<String, dynamic>;
      final displayName =
          (uData["full_name"] ?? uData["name"] ?? name.trim()).toString();

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
          phone: uData["phone"]?.toString(),
          isKycVerified:
              uData["is_kyc_verified"] == 1 || uData["is_kyc_verified"] == true,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);

      // Sync context with native side
      _applyProfile(Map<String, dynamic>.from(res));

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur register API: $e');
      }

      _fail(e);
      return false;
    }
  }

  Future<String?> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    if (email.trim().isEmpty) {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'EMAIL_REQUIRED', errorMessage: '');
      return null;
    }
    try {
      final res = await _apiService.forgotPassword(email.trim());
      state = state.copyWith(isLoading: false);
      // Le serveur ne renvoie un code qu'en développement (`dev_otp`) ; sinon il est envoyé hors application.
      return res['dev_otp']?.toString() ?? '';
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> resetPassword(
      String email, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    if (otp.trim().isEmpty || newPassword.trim().isEmpty) {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'FIELDS_REQUIRED', errorMessage: '');
      return false;
    }
    try {
      await _apiService.resetPassword(
          email.trim(), otp.trim(), newPassword.trim());
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Échec d'un appel d'authentification : erreur réseau traduite par l'écran (code), sinon message du serveur.
  void _fail(Object e, {String? fallbackCode}) {
    if (isNetworkError(e)) {
      state = state.copyWith(isLoading: false, clearError: true, errorCode: 'NETWORK_UNAVAILABLE', errorMessage: '');
      return;
    }
    final msg = e.toString().replaceAll('Exception: ', '');
    state = state.copyWith(isLoading: false, clearError: true, errorCode: msg.isEmpty ? fallbackCode : null, errorMessage: msg);
  }

  /// Connexion et inscription via Google Sign-In (OAuth2 / OIDC)
  Future<bool> loginWithGoogle(
      {String? customEmail, String? customName}) async {
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
      final displayName =
          (uData["full_name"] ?? uData["name"] ?? name).toString();

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
          phone: uData["phone"]?.toString(),
          isKycVerified:
              uData["is_kyc_verified"] == 1 || uData["is_kyc_verified"] == true,
          photoUrl: photoUrl,
          isGoogleAuth: true,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);

      // Sync context with native side
      _applyProfile(Map<String, dynamic>.from(res));
      await _rememberSignInMethod('google');

      return true;
    } on AuthApiException catch (e) {
      // Refus explicite du serveur (connexion Google indisponible ou jeton refusé)
      state = state.copyWith(isLoading: false, errorMessage: e.message, errorCode: e.code);
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] Erreur Google Sign-In: $e');
      }
      final msg = e.toString();
      if (!isNetworkError(e) && (msg.contains('ApiException: 10') || msg.contains('sign_in_failed'))) {
        state = state.copyWith(
          isLoading: false,
          clearError: true,
          errorMessage:
              "Émulateur Android : Clé SHA-1 non configurée sur Google Cloud. Utilisez l'inscription classique par email.",
        );
        return false;
      }
      _fail(e);
      return false;
    }
  }

  Future<void> updateUserInfo(String name, String phone) async {
    try {
      await _authedApi.updateUserInfo(name, phone);
      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(name: name, phone: phone),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] updateUserInfo: $e');
      }
      rethrow;
    }
  }

  /// Envoi des documents d'identité : le serveur les enregistre comme « en attente » ;
  /// seule une vérification PayPal marque le compte comme vérifié.
  Future<void> submitKyc() async {
    try {
      await _authedApi.submitKyc();
      if (state.user != null) {
        state = state.copyWith(user: state.user!.copyWith(kycStatus: 'submitted', isKycVerified: false));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH ERROR] submitKyc: $e');
      }
      rethrow;
    }
  }

  /// Déconnexion sécurisée (Log Out)
  Future<void> logout() async {
    // Ce téléphone ne doit plus recevoir les notifications de ce compte
    await PushNotifications.instance.unregister(_authedApi);
    try {
      await _authedApi.logout();
    } catch (_) {}

    await _secureStorage.clearAll();

    state = AuthState(
      isAuthenticated: false,
      hasSeenOnboarding: true,
      user: null,
      accessToken: null,
      isLoading: false,
    );

    // Clear context from native side
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
