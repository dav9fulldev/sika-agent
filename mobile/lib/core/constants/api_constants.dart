import '../config/app_config.dart';

/// Centralization des chemins d'endpoints de l'API SIKA.
/// L'URL de base est résolue par [AppConfig.baseUrl].
class ApiConstants {
  ApiConstants._();

  /// URL de base résolue selon l'environnement (voir [AppConfig]).
  static String get baseUrl => AppConfig.baseUrl;

  // Auth
  static const String authLogin    = '/api/v1/sika/auth/login';
  static const String authRegister = '/api/v1/sika/auth/register';
  static const String authGoogle   = '/api/v1/sika/auth/google';
  static const String authMe       = '/api/v1/sika/auth/me';
  static const String authLogout   = '/api/v1/sika/auth/logout';
  static const String authForgotPassword = '/api/v1/sika/auth/forgot-password';
  static const String authResetPassword  = '/api/v1/sika/auth/reset-password';

  // Users (KYC & Payment)
  static const String usersMe = '/api/v1/users/me';
  static const String usersKyc = '/api/v1/users/me/kyc';
  static const String usersPaymentMethods = '/api/v1/users/me/payment-methods';

  // Agent SIKA
  static const String sikaHealth       = '/api/v1/sika/health';
  static const String sikaChat         = '/api/v1/sika/chat';
  static const String sikaAgentProcess = '/api/v1/sika/agent/process';
  static const String sikaAgentConfirm = '/api/v1/sika/agent/confirm';
  static const String sikaAgentCancel  = '/api/v1/sika/agent/cancel';
  static const String sikaTts          = '/api/v1/sika/tts';

  // Wallets
  static const String walletsMe          = '/api/v1/wallets/me';
  static const String walletsTxHistory   = '/api/v1/wallets/transactions/history';
  static const String walletsCoffres     = '/api/v1/wallets/coffres';
  static const String walletsConnect     = '/api/v1/wallets/connect';
  static const String walletsVerifyOtp   = '/api/v1/wallets/verify-otp';
  static const String walletsSync        = '/api/v1/wallets/sync';

  // Perception SMS
  static const String perceptionSms      = '/api/v1/perception/sms';
  static const String perceptionSimulate = '/api/v1/perception/simulate';
}

