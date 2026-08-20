class ApiConstants {
  /// Base URL configurable via --dart-define=SIKA_API_URL=... avec fallback sur l'émulateur Android
  static const String baseUrl = String.fromEnvironment(
    'SIKA_API_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );

  static const String sikaHealth = '/api/v1/sika/health';
  static const String sikaChat = '/api/v1/sika/chat';
  static const String sikaAgentConfirm = '/api/v1/sika/agent/confirm';
  static const String sikaAgentProcess = '/api/v1/sika/agent/process';
}
