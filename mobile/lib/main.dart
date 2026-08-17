import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/sika_native_service.dart';
import 'core/constants/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/ai_assistant/presentation/pages/sika_main_navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SikaNativeService.startSikaService();
    debugPrint('[SikaMain] ✅ Service Sika natif démarré en arrière-plan');
  } catch (e) {
    debugPrint('[SikaMain] ⚠️ Erreur lors du démarrage du service Sika: $e');
  }

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
  int _appStep = 0; // 0 = Splash, 1 = Onboarding, 2 = Main Agent Hub

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    switch (_appStep) {
      case 0:
        currentScreen = SplashScreen(
          onFinish: () => setState(() => _appStep = 1),
        );
        break;
      case 1:
        currentScreen = OnboardingScreen(
          onFinish: () => setState(() => _appStep = 2),
        );
        break;
      case 2:
      default:
        currentScreen = const SikaMainNavigationPage();
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
  }
}
