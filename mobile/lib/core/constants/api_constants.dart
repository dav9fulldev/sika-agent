import '../config/app_config.dart';

/// Centralization des chemins d'endpoints de l'API SIKA.
/// L'URL de base est résolue par [AppConfig.baseUrl].
class ApiConstants {
  ApiConstants._();

  /// URL de base résolue selon l'environnement (voir [AppConfig]).
  static String get baseUrl => AppConfig.baseUrl;

  // Auth
  static const String authLogin = '/api/v1/sika/auth/login';
  static const String authRegister = '/api/v1/sika/auth/register';
  static const String authGoogle = '/api/v1/sika/auth/google';
  static const String authPayPalStart = '/api/v1/sika/auth/paypal/start';
  static const String authPayPal = '/api/v1/sika/auth/paypal';
  static const String authMe = '/api/v1/sika/auth/me';
  static const String authLogout = '/api/v1/sika/auth/logout';
  static const String authForgotPassword = '/api/v1/sika/auth/forgot-password';
  static const String authResetPassword = '/api/v1/sika/auth/reset-password';

  // Users (KYC & Payment)
  static const String usersMe = '/api/v1/users/me';
  static const String usersKyc = '/api/v1/users/me/kyc';
  static const String usersPaymentMethods = '/api/v1/users/me/payment-methods';

  // Agent SIKA
  static const String sikaHealth = '/api/v1/sika/health';
  static const String sikaChat = '/api/v1/sika/chat';
  static const String sikaAgentProcess = '/api/v1/sika/agent/process';
  static const String sikaTts = '/api/v1/sika/tts';

  // SIKA Pay — PayPal (sandbox)
  static const String paypalStatus = '/api/v1/paypal/status';
  static const String paypalCheckouts = '/api/v1/paypal/checkouts';
  static const String paypalAgentAuthorization = '/api/v1/paypal/agent-authorization';

  // Perception SMS
  static const String perceptionSms = '/api/v1/perception/sms';
  static const String perceptionSimulate = '/api/v1/perception/simulate';
}
