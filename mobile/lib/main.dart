import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // Ajout requis
import 'core/services/sika_native_service.dart';
import 'core/constants/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
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
  int _appStep = 0; // 0 = Splash, 1 = Onboarding, 2 = Main Agent Hub

  @override
  void initState() {
    super.initState();

    // Attend que l'application soit affichée au premier plan avant d'agir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _demarrerServiceVocalSecurise();
    });
  }

  Future<void> _demarrerServiceVocalSecurise() async {
    try {
      // 1. Demander la permission Microphone à l'utilisateur
      final microStatus = await Permission.microphone.request();

      // 2. Demander la permission Notification (obligatoire pour afficher le service persistant)
      final notificationStatus = await Permission.notification.request();

      // 3. Ne lancer le service natif que si l'accès est pleinement validé
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
    Widget currentScreen;
    switch (_appStep) {
      case 0:
        currentScreen = SplashScreen(
          key: const ValueKey(0), // Recommandé pour le bon fonctionnement de l'AnimatedSwitcher
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
        currentScreen = const SikaMainNavigationPage(key: ValueKey(2));
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
