import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/api_constants.dart';

/// Service HTTP centralisé pour toutes les communications avec l'API SIKA.
///
/// - L'URL de base est résolue par [AppConfig.baseUrl] (voir ce fichier pour
///   la stratégie de résolution development / production / override).
/// - Toutes les requêtes disposent d'un timeout configuré dans [AppConfig].
/// - L'en-tête Authorization Bearer JWT est ajouté automatiquement si [token]
///   est défini.
/// - Le callback [onUnauthorized] est déclenché sur toute réponse HTTP 401
///   pour permettre au provider parent de gérer la déconnexion.
class ApiService {
  final String baseUrl;
  String? token;

  /// Callback déclenché lors d'une réponse HTTP 401 (token expiré / révoqué).
  void Function()? onUnauthorized;

  ApiService({String? baseUrl, this.onUnauthorized})
      : baseUrl = baseUrl ?? AppConfig.baseUrl;

  bool get hasToken => token != null && token!.isNotEmpty;

  /// URL sécurisée : force HTTPS en release sur les endpoints non-locaux.
  String get safeBaseUrl {
    if (!kReleaseMode) return baseUrl;
    if (baseUrl.startsWith('http://') &&
        !baseUrl.contains('10.0.2.2') &&
        !baseUrl.contains('127.0.0.1') &&
        !baseUrl.contains('localhost')) {
      return baseUrl.replaceFirst('http://', 'https://');
    }
    return baseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $token',
      };

  // ============================================================================
  // ERROR & RESPONSE HANDLING
  // ============================================================================

  void _handleStatusCode(int statusCode) {
    if (statusCode == 401) {
      onUnauthorized?.call();
    }
  }

  String _extractErrorMessage(http.Response response, String fallbackPrefix) {
    _handleStatusCode(response.statusCode);
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return '$fallbackPrefix (${response.statusCode})';
  }

  // ============================================================================
  // OAUTH2 AUTHENTICATION API ENDPOINTS
  // ============================================================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.authLogin}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response, 'Erreur de connexion'));
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.authRegister}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body:
              jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response, "Erreur d'inscription"));
  }

  Future<Map<String, dynamic>> googleLogin({
    String? idToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.authGoogle}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({
            if (idToken != null) 'id_token': idToken,
            if (email != null) 'email': email,
            if (name != null) 'name': name,
            if (photoUrl != null) 'photo_url': photoUrl,
          }),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response, 'Erreur Google Sign-In'));
  }

  Future<Map<String, dynamic>> getMe(String bearerToken) async {
    final response = await http.get(
      Uri.parse('$safeBaseUrl${ApiConstants.authMe}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
    ).timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Jeton OAuth2 invalide (${response.statusCode})');
  }

  Future<void> logout() async {
    try {
      if (hasToken) {
        await http
            .post(
              Uri.parse('$safeBaseUrl${ApiConstants.authLogout}'),
              headers: _headers,
            )
            .timeout(AppConfig.defaultTimeout);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.authForgotPassword}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({'email': email}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(
        response, 'Erreur lors de la demande de réinitialisation'));
  }

  Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newPassword) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.authResetPassword}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode(
              {'email': email, 'otp': otp, 'new_password': newPassword}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(
        _extractErrorMessage(response, 'Erreur lors de la réinitialisation'));
  }

  // ============================================================================
  // USER PROFILE & KYC API ENDPOINTS
  // ============================================================================

  Future<void> updateUserInfo(String name, String phone) async {
    final response = await http
        .put(
          Uri.parse('$safeBaseUrl${ApiConstants.usersMe}'),
          headers: _headers,
          body: jsonEncode({'name': name, 'phone': phone}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Erreur de mise à jour'));
    }
  }

  Future<void> submitKyc() async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.usersKyc}'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Erreur KYC'));
    }
  }

  // ============================================================================
  // PAYMENT METHODS API ENDPOINTS
  // ============================================================================

  Future<List<dynamic>> getPaymentMethods() async {
    final response = await http
        .get(
          Uri.parse('$safeBaseUrl${ApiConstants.usersPaymentMethods}'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        _extractErrorMessage(response, 'Erreur récupération des cartes'));
  }

  Future<Map<String, dynamic>> addPaymentMethod(
      Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.usersPaymentMethods}'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response, 'Erreur ajout méthode'));
  }

  Future<void> deletePaymentMethod(String id) async {
    final response = await http
        .delete(
          Uri.parse('$safeBaseUrl${ApiConstants.usersPaymentMethods}/$id'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response, 'Erreur suppression'));
    }
  }

  Future<void> setDefaultPaymentMethod(String id) async {
    final response = await http
        .put(
          Uri.parse(
              '$safeBaseUrl${ApiConstants.usersPaymentMethods}/$id/default'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
          _extractErrorMessage(response, 'Erreur mise à jour défaut'));
    }
  }

  // ============================================================================
  // SIKA AI & AGENT CONVERSATION
  // ============================================================================

  Future<Map<String, dynamic>> sikaChat(
    String query, {
    String? userFirstName,
    String? currencyCode,
    String? currencySymbol,
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.sikaChat}'),
          headers: _headers,
          body: jsonEncode({
            'query': query,
            'context': {
              'user_firstname': userFirstName ?? 'Utilisateur',
              'currency_code': currencyCode ?? 'XOF',
              'currency_symbol': currencySymbol ?? 'FCFA',
            }
          }),
        )
        .timeout(AppConfig.agentTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception(
        'Failed to communicate with SIKA AI: ${response.statusCode}');
  }

  // ============================================================================
  // WALLET & TRANSACTION ENDPOINTS (AUTHENTICATED)
  // ============================================================================

  Future<Map<String, dynamic>> fetchMyWallets() async {
    final response = await http
        .get(
          Uri.parse('$safeBaseUrl${ApiConstants.walletsMe}'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to fetch wallets: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchWalletTransactionHistory(
      {int limit = 30}) async {
    final response = await http
        .get(
          Uri.parse(
              '$safeBaseUrl${ApiConstants.walletsTxHistory}?limit=$limit'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception(
        'Failed to fetch transaction movements: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchUserCoffres() async {
    final response = await http
        .get(
          Uri.parse('$safeBaseUrl${ApiConstants.walletsCoffres}'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to fetch user coffres: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> connectWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.walletsConnect}'),
          headers: _headers,
          body: jsonEncode({
            'provider': provider,
            'account_number': accountNumber,
            'auth_method': authMethod,
          }),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    String errorMsg =
        'Échec de la demande de connexion (${response.statusCode})';
    try {
      final errObj = jsonDecode(response.body);
      if (errObj is Map && errObj['detail'] != null) {
        errorMsg = errObj['detail'].toString();
      }
    } catch (_) {}
    throw Exception(errorMsg);
  }

  Future<Map<String, dynamic>> verifyWalletOtp({
    required String sessionId,
    required String otpCode,
    required String provider,
    required String accountNumber,
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.walletsVerifyOtp}'),
          headers: _headers,
          body: jsonEncode({
            'session_id': sessionId,
            'otp_code': otpCode,
            'provider': provider,
            'account_number': accountNumber,
          }),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    String errorMsg = 'Échec de la validation OTP (${response.statusCode})';
    try {
      final errObj = jsonDecode(response.body);
      if (errObj is Map && errObj['detail'] != null) {
        errorMsg = errObj['detail'].toString();
      }
    } catch (_) {}
    throw Exception(errorMsg);
  }

  Future<Map<String, dynamic>> syncWallets() async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.walletsSync}'),
          headers: _headers,
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    String errorMsg = 'Échec de la synchronisation (${response.statusCode})';
    try {
      final errObj = jsonDecode(response.body);
      if (errObj is Map && errObj['detail'] != null) {
        errorMsg = errObj['detail'].toString();
      }
    } catch (_) {}
    throw Exception(errorMsg);
  }

  // ============================================================================
  // SMS PERCEPTION
  // ============================================================================

  Future<Map<String, dynamic>> perceiveSms({
    required String text,
    String sender = 'WAVE',
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.perceptionSms}'),
          headers: _headers,
          body: jsonEncode({'text': text, 'sender': sender}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to send SMS perception: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> simulateSmsPerception(String smsText) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.perceptionSimulate}'),
          headers: _headers,
          body: jsonEncode({'sms_text': smsText, 'sender': 'WAVE'}),
        )
        .timeout(AppConfig.defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception(
        'Failed to simulate SMS perception: ${response.statusCode}');
  }

  // ============================================================================
  // AGENT FINANCIAL ACTIONS (CONFIRM / RECONCILE)
  // ============================================================================

  Future<Map<String, dynamic>> sikaAgentConfirm(String actionId) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.sikaAgentConfirm}'),
          headers: _headers,
          body: jsonEncode({'action_id': actionId}),
        )
        .timeout(AppConfig.agentTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to confirm agent action: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> sikaReconcileAction(String actionId) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl/api/v1/sika/actions/$actionId/reconcile'),
          headers: _headers,
        )
        .timeout(AppConfig.agentTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to reconcile agent action: ${response.statusCode}');
  }

  // ============================================================================
  // TTS (TEXT-TO-SPEECH via GCP / Cloud Run)
  // ============================================================================

  Future<Map<String, dynamic>> fetchGcpTtsAudio(
    String text, {
    String voiceName = 'fr-FR-Neural2-C',
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.sikaTts}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({
            'text': text,
            'voice_name': voiceName,
            'speaking_rate': 1.05,
          }),
        )
        .timeout(AppConfig.agentTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate GCP TTS audio: ${response.statusCode}');
  }
}
