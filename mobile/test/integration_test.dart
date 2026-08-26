import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/auth_provider.dart';
import 'package:sika_assistant_mobile/core/providers/api_service_provider.dart';
import 'package:sika_assistant_mobile/features/wallet/providers/wallet_provider.dart';
import 'package:sika_assistant_mobile/features/ai_assistant/providers/sika_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SIKA Frontend Integration & Security Tests', () {
    test('apiServiceProvider propagates token from authProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final apiService = container.read(apiServiceProvider);
      expect(apiService.hasToken, isFalse);

      // Simuler une connexion dans AuthProvider
      container.read(authProvider.notifier).state = AuthState(
        isAuthenticated: true,
        accessToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test_token',
        user: UserProfileData(
            id: '1', name: 'David YAO', email: 'david@sika.app'),
      );

      // Le token doit être automatiquement synchronisé sur l'ApiService partagé
      expect(apiService.token,
          equals('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test_token'));
      expect(apiService.hasToken, isTrue);
    });

    test('401 unauthorized callback triggers auto-logout', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final apiService = container.read(apiServiceProvider);
      container.read(authProvider.notifier).state = AuthState(
        isAuthenticated: true,
        accessToken: 'test_token',
        user: UserProfileData(
            id: '1', name: 'David YAO', email: 'david@sika.app'),
      );
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Déclencher le callback 401
      apiService.onUnauthorized?.call();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).accessToken, isNull);
    });

    test('AuthNotifier.logout clears local session and resets state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authProvider.notifier);
      authNotifier.state = AuthState(
        isAuthenticated: true,
        accessToken: 'test_active_jwt_token',
        user: UserProfileData(
            id: '1', name: 'David YAO', email: 'david@sika.app'),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sika_access_token', 'test_active_jwt_token');

      await authNotifier.logout();

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).accessToken, isNull);
      expect(container.read(authProvider).user, isNull);
      expect(prefs.getString('sika_access_token'), isNull);
    });

    test('WalletNotifier.clearData resets all wallet balances and movements',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final walletNotifier = container.read(walletProvider.notifier);
      walletNotifier.state = WalletState(
        wallets: [
          ConnectedWalletItem(
            id: 'w1',
            provider: 'Wave',
            accountNumber: '0701020304',
            balance: 50000.0,
            currency: 'XOF',
            authMethod: 'OAUTH2_API',
            isActive: true,
            lastSyncedAt: '2026-08-20T12:00:00Z',
          ),
        ],
        movements: [
          WalletMovementItem(
            id: 'm1',
            type: 'transfer',
            amount: 10000.0,
            currency: 'XOF',
            category: 'Transfert',
            recipient: 'Kouamé',
            description: 'Envoi',
            status: 'COMPLETED',
            timestamp: '2026-08-20T12:00:00Z',
            walletProvider: 'Wave',
          ),
        ],
      );

      expect(container.read(walletProvider).wallets.length, equals(1));
      expect(container.read(walletProvider).totalBalanceFcfa, equals(50000.0));

      // Exécuter le nettoyage de déconnexion
      walletNotifier.clearData();

      expect(container.read(walletProvider).wallets.isEmpty, isTrue);
      expect(container.read(walletProvider).movements.isEmpty, isTrue);
      expect(container.read(walletProvider).totalBalanceFcfa, equals(0.0));
    });

    test('SikaNotifier.clearConversation resets pending action and messages',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sikaNotifier = container.read(sikaProvider.notifier);
      sikaNotifier.state = SikaData(
        state: SikaState.securityValidation,
        messages: [SikaMessage(text: 'Transfert 10 000 FCFA', isUser: false)],
        pendingActionId: 'act_123456',
        pendingActionData: {'amount': 10000.0, 'recipient': 'Kouamé'},
      );

      expect(
          container.read(sikaProvider).pendingActionId, equals('act_123456'));

      sikaNotifier.clearConversation();

      expect(container.read(sikaProvider).messages.isEmpty, isTrue);
      expect(container.read(sikaProvider).pendingActionId, isNull);
      expect(container.read(sikaProvider).pendingActionData, isNull);
      expect(container.read(sikaProvider).state, equals(SikaState.idle));
    });
  });
}
