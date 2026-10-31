import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

/// Navigateur et messagerie de l'app : permettent d'ouvrir l'écran des notifications depuis un push.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Notifications push (Firebase Cloud Messaging) : le téléphone s'enregistre auprès du serveur SIKA,
/// qui l'utilise pour prévenir des changements de prix et de stock. Sans configuration Firebase
/// (google-services.json absent), rien ne se passe : les notifications restent visibles dans l'app.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  bool _firebaseReady = false;
  bool _listening = false;
  String? _token;

  /// Push reçu app ouverte (titre, texte).
  void Function(String title, String body)? onForeground;

  /// Push touché dans la barre de notifications.
  VoidCallback? onOpened;

  Future<bool> _initFirebase() async {
    if (_firebaseReady) return true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('[PUSH] Firebase is not configured: ${e.runtimeType}');
    }
    return _firebaseReady;
  }

  Future<void> register(ApiService api, {required String language}) async {
    if (!await _initFirebase()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      // Android 13+ : demande l'autorisation d'afficher des notifications
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      // Jeton d'enregistrement classique : c'est la cible documentée du champ `token` de l'API FCM HTTP v1
      // utilisée par le serveur (le nouvel identifiant d'installation de register() n'est pas encore pris en charge).
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null) return;
      _token = token;
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      await api.registerPushDevice(token, language: language, tzOffsetMinutes: offset);
      if (_listening) return;
      _listening = true;
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((fresh) {
        _token = fresh;
        api.registerPushDevice(fresh, language: language, tzOffsetMinutes: offset).catchError((_) => <String, dynamic>{});
      });
      FirebaseMessaging.onMessage.listen((m) => onForeground?.call(m.notification?.title ?? '', m.notification?.body ?? ''));
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpened?.call());
      if (await messaging.getInitialMessage() != null) onOpened?.call();
    } catch (e) {
      debugPrint('[PUSH] Registration failed: ${e.runtimeType}');
    }
  }

  /// À la déconnexion : ce téléphone ne reçoit plus les notifications de ce compte.
  Future<void> unregister(ApiService api) async {
    final token = _token;
    if (token == null) return;
    _token = null;
    try {
      await api.removePushDevice(token);
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
