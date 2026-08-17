import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/sika_native_service.dart';
import 'core/constants/app_theme.dart';
import 'features/ai_assistant/presentation/pages/sika_main_navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SikaNativeService.startSikaService();
    debugPrint('[SikaMain] ✅ Service Sika natif démarré');
  } catch (e) {
    debugPrint('[SikaMain] ⚠️ Erreur lors du démarrage du service Sika: $e');
  }

  runApp(
    const ProviderScope(
      child: SikaApp(),
    ),
  );
}

class SikaApp extends StatelessWidget {
  const SikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIKA Assistant',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SikaMainNavigationPage(),
    );
  }
}
