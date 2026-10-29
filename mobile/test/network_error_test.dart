import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sika_assistant_mobile/core/utils/network_error.dart';

void main() {
  test('offline errors are recognised as network errors', () {
    // Message réel affiché sur le téléphone sans connexion
    final offline = http.ClientException(
      "SocketFailed host lookup: 'sika-backend.example.run.app' (OS Error: No address associated with hostname, errno = 7)",
      Uri.parse('https://sika-backend.example.run.app/api/v1/sika/auth/paypal/start'),
    );
    expect(isNetworkError(offline), isTrue);
    expect(isNetworkError(const SocketException('Connection refused')), isTrue);
    expect(isNetworkError(TimeoutException('slow')), isTrue);
    expect(isNetworkError(Exception('Failed host lookup: api')), isTrue);
  });

  test('server answers are not network errors', () {
    expect(isNetworkError(Exception('Invalid email or password')), isFalse);
    expect(isNetworkError(const FormatException('bad json')), isFalse);
  });
}
