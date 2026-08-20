import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final String baseUrl;
  String? token;

  ApiService({this.baseUrl = ApiConstants.baseUrl});

  bool get hasToken => token != null && token!.isNotEmpty;

  // ============================================================================
  // OAUTH2 AUTHENTICATION API ENDPOINTS
  // ============================================================================

  String _extractErrorMessage(http.Response response, String fallbackPrefix) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return '$fallbackPrefix (${response.statusCode})';
  }

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

  Future<Map<String, dynamic>> googleLogin({String email = "david.yao@gmail.com", String name = "David YAO"}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sika/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
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
    throw Exception('Jeton OAuth2 invalide (${response.statusCode})');
  }

  Future<Map<String, dynamic>> sikaChat(
    String query, {
    String? userFirstName,
    String? currencyCode,
    String? currencySymbol,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl${ApiConstants.sikaChat}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'context': {
          'user_id': 1,
          'user_firstname': userFirstName ?? "David",
          'currency_code': currencyCode ?? "USD",
          'currency_symbol': currencySymbol ?? "\$",
        }
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to communicate with SIKA AI: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchMyWallets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/me'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch wallets: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchWalletTransactionHistory({int limit = 30}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/transactions/history?limit=$limit'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch transaction movements: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchUserCoffres() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/wallets/coffres'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch user coffres: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> connectWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'account_number': accountNumber,
        'auth_method': authMethod,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to initiate wallet connection: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> verifyWalletOtp({
    required String sessionId,
    required String otpCode,
    required String provider,
    required String accountNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/verify-otp'),
      headers: {'Content-Type': 'application/json'},
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
    throw Exception('Failed to verify OTP: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> perceiveSms({
    required String text,
    String sender = 'WAVE',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/perception/sms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'sender': sender,
        'user_id': 1,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send SMS perception: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> simulateSmsPerception(String smsText) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/perception/simulate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sms_text': smsText,
        'sender': 'WAVE',
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to simulate SMS perception: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> syncWallets() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/sync'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to sync wallets: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> sikaConfirmTransaction({
    required double amount,
    required String category,
    String? description,
  }) async {
    return createTransaction(amount: amount, category: category, description: description);
  }

  Future<Map<String, dynamic>> createTransaction({
    required double amount,
    required String category,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl${ApiConstants.sikaConfirm}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'category': category,
        'description': description ?? 'Dépense via Sika',
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create transaction: ${response.statusCode}');
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
