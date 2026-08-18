import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final String baseUrl;
  String? token;

  ApiService({this.baseUrl = ApiConstants.baseUrl});

  bool get hasToken => true;

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

  Future<Map<String, dynamic>> connectWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
    double initialBalance = 10000.0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/wallets/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'account_number': accountNumber,
        'auth_method': authMethod,
        'initial_balance': initialBalance,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to connect wallet: ${response.statusCode}');
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
}
