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
    String? displayCurrencyCode,
    String? displayCurrencySymbol,
    String? language,
  }) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.sikaChat}'),
          headers: _headers,
          body: jsonEncode({
            'query': query,
            'context': {
              'user_firstname': userFirstName ?? 'Utilisateur',
              'display_currency_code': displayCurrencyCode ?? 'XOF',
              'display_currency_symbol': displayCurrencySymbol ?? 'XOF',
              'language': language ?? 'fr',
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
  // SIKA PAY — PAYPAL CHECKOUTS (SANDBOX)
  // Le backend calcule les montants et parle à PayPal ; l'application ne fait
  // qu'afficher les statuts renvoyés et transmettre les décisions de l'utilisateur.
  // ============================================================================

  Map<String, dynamic> _decodePayPal(http.Response response) {
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    _handleStatusCode(response.statusCode);
    String code = 'HTTP_${response.statusCode}';
    String message = 'SIKA Pay request failed (${response.statusCode}).';
    Map<String, dynamic>? checkout;
    try {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      if (detail is Map) {
        code = detail['error_code']?.toString() ?? code;
        message = detail['message']?.toString() ?? message;
        if (detail['checkout'] is Map) {
          checkout = Map<String, dynamic>.from(detail['checkout']);
        }
      } else if (detail != null) {
        message = detail.toString();
      }
    } catch (_) {}
    throw PayPalApiException(code, message, response.statusCode, checkout: checkout);
  }

  Future<Map<String, dynamic>> getPayPalStatus() async {
    final response = await http
        .get(Uri.parse('$safeBaseUrl${ApiConstants.paypalStatus}'), headers: _headers)
        .timeout(AppConfig.agentTimeout);
    return _decodePayPal(response);
  }

  Future<Map<String, dynamic>> getPayPalCheckout(String checkoutId, {bool sync = false}) async {
    final response = await http
        .get(
          Uri.parse('$safeBaseUrl${ApiConstants.paypalCheckouts}/$checkoutId${sync ? '?sync=true' : ''}'),
          headers: _headers,
        )
        .timeout(AppConfig.agentTimeout);
    return _decodePayPal(response);
  }

  Future<List<dynamic>> listPayPalCheckouts({int limit = 20}) async {
    final response = await http
        .get(
          Uri.parse('$safeBaseUrl${ApiConstants.paypalCheckouts}?limit=$limit'),
          headers: _headers,
        )
        .timeout(AppConfig.agentTimeout);
    return (_decodePayPal(response)['checkouts'] as List<dynamic>? ?? []);
  }

  /// Confirmation explicite : le backend crée la commande PayPal sandbox et renvoie le lien d'approbation.
  Future<Map<String, dynamic>> confirmPayPalCheckout(String checkoutId, String detailsHash) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.paypalCheckouts}/$checkoutId/confirm'),
          headers: _headers,
          body: jsonEncode({'details_hash': detailsHash}),
        )
        .timeout(AppConfig.agentTimeout);
    return _decodePayPal(response);
  }

  /// Capture : refusée par le backend tant que PayPal ne confirme pas l'approbation.
  Future<Map<String, dynamic>> capturePayPalCheckout(String checkoutId) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.paypalCheckouts}/$checkoutId/capture'),
          headers: _headers,
        )
        .timeout(AppConfig.agentTimeout);
    return _decodePayPal(response);
  }

  Future<Map<String, dynamic>> cancelPayPalCheckout(String checkoutId) async {
    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.paypalCheckouts}/$checkoutId/cancel'),
          headers: _headers,
          body: jsonEncode({'reason': 'USER_CANCELLED_IN_APP'}),
        )
        .timeout(AppConfig.agentTimeout);
    return _decodePayPal(response);
  }

  // ============================================================================
  // PERCEPTION (notifications SMS interceptées par l'application)
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

  // ============================================================================
  // TTS (TEXT-TO-SPEECH via GCP / Cloud Run)
  // ============================================================================

  Future<Map<String, dynamic>> fetchGcpTtsAudio(
    String text, {
    String? voiceName,
    String? languageCode,
  }) async {
    final body = <String, dynamic>{
      'text': text,
      'speaking_rate': 1.05,
    };
    if (voiceName != null) body['voice_name'] = voiceName;
    if (languageCode != null) body['language_code'] = languageCode;

    final response = await http
        .post(
          Uri.parse('$safeBaseUrl${ApiConstants.sikaTts}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode(body),
        )
        .timeout(AppConfig.agentTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate GCP TTS audio: ${response.statusCode}');
  }
}

/// Erreur métier renvoyée par les endpoints SIKA Pay (code stable + message lisible).
class PayPalApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? checkout;

  PayPalApiException(this.code, this.message, this.statusCode, {this.checkout});

  @override
  String toString() => message;
}
