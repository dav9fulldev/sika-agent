import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/app_setup_provider.dart';
import 'package:sika_assistant_mobile/core/providers/auth_provider.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/core/services/biometric_service.dart';
import 'package:sika_assistant_mobile/features/auth/presentation/pages/welcome_screen.dart';
import 'package:sika_assistant_mobile/features/entry/biometric_lock_screen.dart';
import 'package:sika_assistant_mobile/features/entry/complete_profile_screen.dart';
import 'package:sika_assistant_mobile/features/entry/biometric_setup_screen.dart';
import 'package:sika_assistant_mobile/features/splash/loading_screen.dart';

class _NoBiometrics extends BiometricService {
  @override
  Future<bool> isBiometricsAvailable() async => false;
}

class _FailingBiometrics extends BiometricService {
  @override
  Future<bool> isBiometricsAvailable() async => true;
  @override
  Future<bool> authenticate({String localizedReason = ''}) async => false;
}

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: [
        languageProvider.overrideWith((ref) => LanguageNotifier()..setLanguage(AppLanguage.french)),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loading screen tells the user what is happening', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SikaLoadingScreen()));
    expect(find.text('Chargement de votre assistant IA…'), findsOneWidget);
  });

  testWidgets('welcome screen is the email login with Google and PayPal below', (tester) async {
    await tester.pumpWidget(_app(const WelcomeScreen()));
    await tester.pump();
    expect(find.text('Bienvenue sur SIKA Pay'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Ou continuer avec'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.textContaining('Continuer avec'), findsNothing);
  });

  testWidgets('PayPal account on the email form is told to use PayPal, in the app language', (tester) async {
    await tester.pumpWidget(_app(const WelcomeScreen(), overrides: [
      authProvider.overrideWith((ref) => AuthNotifier.withState(
          AuthState(errorCode: 'USE_PAYPAL_SIGN_IN', errorMessage: 'This account uses PayPal sign-in.'))),
    ]));
    await tester.pump();
    expect(find.textContaining('Ce compte utilise la connexion PayPal'), findsOneWidget);
  });

  testWidgets('biometric step is skipped when the device has no biometrics', (tester) async {
    final container = ProviderContainer(overrides: [biometricServiceProvider.overrideWithValue(_NoBiometrics())]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: BiometricLockScreen())));
    await tester.pumpAndSettle();
    expect(container.read(appSetupProvider).unlocked, isTrue);
  });

  testWidgets('failed fingerprint keeps the session locked and explains why', (tester) async {
    final container = ProviderContainer(overrides: [
      biometricServiceProvider.overrideWithValue(_FailingBiometrics()),
      languageProvider.overrideWith((ref) => LanguageNotifier()..setLanguage(AppLanguage.french)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: BiometricLockScreen())));
    await tester.pumpAndSettle();
    expect(container.read(appSetupProvider).unlocked, isFalse);
    expect(find.textContaining('Identité non confirmée'), findsOneWidget);
    expect(find.text('Utiliser le mot de passe'), findsOneWidget);
  });

  testWidgets('biometric setup is skipped and recorded when the device has no biometrics', (tester) async {
    final container = ProviderContainer(overrides: [biometricServiceProvider.overrideWithValue(_NoBiometrics())]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: BiometricSetupScreen())));
    await tester.pump();
    await tester.pump();
    expect(container.read(appSetupProvider).biometricDecided, isTrue);
    expect(container.read(appSetupProvider).biometricEnabled, isFalse);
  });

  testWidgets('biometric setup can be postponed', (tester) async {
    final container = ProviderContainer(overrides: [
      biometricServiceProvider.overrideWithValue(_FailingBiometrics()),
      languageProvider.overrideWith((ref) => LanguageNotifier()..setLanguage(AppLanguage.french)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: BiometricSetupScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Plus tard'));
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(container.read(appSetupProvider).biometricDecided, isTrue);
    expect(container.read(appSetupProvider).biometricEnabled, isFalse);
  });

  testWidgets('profile screen requires a full name', (tester) async {
    await tester.pumpWidget(_app(const CompleteProfileScreen(), overrides: [
      authProvider.overrideWith((ref) => AuthNotifier.withState(AuthState(
            isAuthenticated: true,
            user: UserProfileData(id: '1', name: '', email: 'a@example.com', missingFields: const ['full_name', 'country']),
          ))),
    ]));
    await tester.pump();
    expect(find.text('Finalisez votre profil'), findsOneWidget);
    expect(find.text('Pays de résidence'), findsOneWidget);
    expect(find.text('Identité non vérifiée'), findsOneWidget);
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(find.text('Indiquez votre nom complet.'), findsOneWidget);
  });

  testWidgets('profile screen asks only for missing fields and shows PayPal verification', (tester) async {
    await tester.pumpWidget(_app(const CompleteProfileScreen(), overrides: [
      authProvider.overrideWith((ref) => AuthNotifier.withState(AuthState(
            isAuthenticated: true,
            user: UserProfileData(
                id: '1', name: 'Awa Koné', email: 'a@example.com', missingFields: const ['country'], kycStatus: 'paypal'),
          ))),
    ]));
    await tester.pump();
    expect(find.text('Nom complet'), findsNothing);
    expect(find.text('Pays de résidence'), findsOneWidget);
    expect(find.text('Identité vérifiée par PayPal'), findsOneWidget);
    expect(find.text('Vérifier mon identité'), findsNothing);
  });
}
