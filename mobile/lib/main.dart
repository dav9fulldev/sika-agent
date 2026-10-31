import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/app_setup_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/push_notifications.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/loading_screen.dart';
import 'features/auth/presentation/pages/welcome_screen.dart';
import 'features/entry/biometric_lock_screen.dart';
import 'features/entry/biometric_setup_screen.dart';
import 'features/entry/complete_profile_screen.dart';
import 'features/ai_assistant/presentation/pages/sika_main_navigation_page.dart';
import 'features/ai_assistant/providers/sika_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: SikaApp(),
    ),
  );
}

class SikaApp extends ConsumerStatefulWidget {
  const SikaApp({super.key});

  @override
  ConsumerState<SikaApp> createState() => _SikaAppState();
}

class _SikaAppState extends ConsumerState<SikaApp> {
  bool _splashFinished = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final setup = ref.watch(appSetupProvider);

    // Déconnexion : effacement de la conversation et verrouillage de la session suivante
    ref.listen<AuthState>(authProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) && !next.isAuthenticated) {
        debugPrint('[AUTH] Déconnexion détectée — vidage de la conversation SIKA.');
        ref.read(sikaProvider.notifier).clearConversation();
        ref.read(appSetupProvider.notifier).lock();
      }
    });

    final Widget currentScreen;
    if (!_splashFinished) {
      // 1. Démarrage
      currentScreen = SplashScreen(
        key: const ValueKey('splash'),
        onFinish: () => setState(() => _splashFinished = true),
      );
    } else if (authState.isRestoring || !setup.loaded) {
      // 2. Chargement : restauration de la session enregistrée
      currentScreen = const SikaLoadingScreen(key: ValueKey('loading'));
    } else if (!authState.isAuthenticated) {
      // 3. Bienvenue : Google, PayPal ou e-mail
      currentScreen = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (!setup.biometricDecided) {
      // 4. Sécurisation, proposée une fois (passée sans capteur)
      currentScreen = const BiometricSetupScreen(key: ValueKey('biometric_setup'));
    } else if (authState.restoredSession && setup.biometricEnabled && !setup.unlocked) {
      // 5. Empreinte pour une session restaurée au lancement
      currentScreen = const BiometricLockScreen(key: ValueKey('biometric'));
    } else if (authState.user?.missingFields.isNotEmpty ?? false) {
      // 6. Profil : uniquement les champs que le mode de connexion n'a pas fournis
      currentScreen = const CompleteProfileScreen(key: ValueKey('profile'));
    } else {
      // 7. Accueil
      currentScreen = const SikaMainNavigationPage(key: ValueKey('main_hub'));
    }

    return MaterialApp(
      title: 'SIKA Pay',
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: currentScreen,
      ),
    );
  }
}
