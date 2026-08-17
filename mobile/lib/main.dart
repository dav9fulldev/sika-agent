import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/sika_native_service.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/ai_assistant/presentation/pages/sika_main_navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: SikaApp(),
    ),
  );
}

class SikaApp extends StatefulWidget {
  const SikaApp({super.key});

  @override
  State<SikaApp> createState() => _SikaAppState();
}

class _SikaAppState extends State<SikaApp> {
  int _appStep = 0; // 0 = Splash, 1 = Onboarding, 2 = Auth / Login, 3 = Main Agent Hub

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _demarrerServiceVocalSecurise();
    });
  }

  Future<void> _demarrerServiceVocalSecurise() async {
    try {
      final microStatus = await Permission.microphone.request();
      final notificationStatus = await Permission.notification.request();

      if (microStatus.isGranted && notificationStatus.isGranted) {
        await SikaNativeService.startSikaService();
        debugPrint('[SikaMain] ✅ Service Sika natif démarré avec succès au premier plan');
      } else {
        debugPrint('[SikaMain] ⚠️ Permissions refusées. Impossible de lancer le service d\'écoute.');
      }
    } catch (e) {
      debugPrint('[SikaMain] ⚠️ Erreur lors du démarrage du service Sika: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authProvider);

        Widget currentScreen;
        switch (_appStep) {
          case 0:
            currentScreen = SplashScreen(
              key: const ValueKey(0),
              onFinish: () => setState(() => _appStep = 1),
            );
            break;
          case 1:
            currentScreen = OnboardingScreen(
              key: const ValueKey(1),
              onFinish: () => setState(() => _appStep = 2),
            );
            break;
          case 2:
          default:
            if (authState.isAuthenticated) {
              currentScreen = const SikaMainNavigationPage(key: ValueKey(3));
            } else {
              currentScreen = const LoginScreen(key: ValueKey(2));
            }
            break;
        }

        return MaterialApp(
          title: 'SIKA Assistant',
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: currentScreen,
          ),
        );
      },
    );
  }
}
