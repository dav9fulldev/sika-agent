import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final String baseUrl;
  String? token;

  ApiService({this.baseUrl = ApiConstants.baseUrl});

  bool get hasToken => true;

  Future<Map<String, dynamic>> sikaChat(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl${ApiConstants.sikaChat}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'context': {
          'user_id': 1,
          'user_firstname': "l'ami",
        }
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to communicate with SIKA AI: ${response.statusCode}');
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
