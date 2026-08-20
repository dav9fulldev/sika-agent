import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final String baseUrl;
  String? token;
  void Function()? onUnauthorized;

  ApiService({this.baseUrl = ApiConstants.baseUrl, this.onUnauthorized});

  bool get hasToken => token != null && token!.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response, 'Erreur de connexion'));
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response, 'Erreur d\'inscription'));
  }

  Future<Map<String, dynamic>> googleLogin({
    String? idToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (idToken != null) 'id_token': idToken,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response, 'Erreur Google Sign-In'));
  }

  Future<Map<String, dynamic>> getMe(String bearerToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/sika/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Jeton OAuth2 invalide (${response.statusCode})');
  }

  Future<void> logout() async {
    try {
      if (hasToken) {
        await http.post(
          Uri.parse('$baseUrl/api/v1/sika/auth/logout'),
          headers: _headers,
        );
      }
    } catch (_) {}
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
    final response = await http.post(
      Uri.parse('$baseUrl${ApiConstants.sikaChat}'),
      headers: _headers,
      body: jsonEncode({
        'query': query,
        'context': {
          'user_firstname': userFirstName ?? "David",
          'currency_code': currencyCode ?? "XOF",
          'currency_symbol': currencySymbol ?? "FCFA",
        }
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to communicate with SIKA AI: ${response.statusCode}');
  }

  // ============================================================================
  // WALLET & TRANSACTION ENDPOINTS (AUTHENTICATED)
  // ============================================================================

  Future<Map<String, dynamic>> fetchMyWallets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/me'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to fetch wallets: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchWalletTransactionHistory({int limit = 30}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/transactions/history?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to fetch transaction movements: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchUserCoffres() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/coffres'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to fetch user coffres: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> connectWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/connect'),
      headers: _headers,
      body: jsonEncode({
        'provider': provider,
        'account_number': accountNumber,
        'auth_method': authMethod,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    String errorMsg = 'Échec de la demande de connexion (${response.statusCode})';
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/verify-otp'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
        'otp_code': otpCode,
        'provider': provider,
        'account_number': accountNumber,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/sync'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/perception/sms'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'sender': sender,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to send SMS perception: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> simulateSmsPerception(String smsText) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/perception/simulate'),
      headers: _headers,
      body: jsonEncode({
        'sms_text': smsText,
        'sender': 'WAVE',
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to simulate SMS perception: ${response.statusCode}');
  }

  // ============================================================================
  // AGENT FINANCIAL ACTIONS (CONFIRM / RECONCILE)
  // ============================================================================

  Future<Map<String, dynamic>> sikaAgentConfirm(String actionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/agent/confirm'),
      headers: _headers,
      body: jsonEncode({
        'action_id': actionId,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to confirm agent action: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> sikaReconcileAction(String actionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/actions/$actionId/reconcile'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    _handleStatusCode(response.statusCode);
    throw Exception('Failed to reconcile agent action: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchGcpTtsAudio(String text, {String voiceName = 'fr-FR-Neural2-C'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/tts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'voice_name': voiceName,
        'speaking_rate': 1.05,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate GCP TTS audio: ${response.statusCode}');
  }
}
