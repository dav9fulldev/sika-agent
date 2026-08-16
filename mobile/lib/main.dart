import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/sika_native.dart';
import 'features/ai_assistant/presentation/pages/sika_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Démarrage du service vocal Sika natif
  try {
    await SikaNative.startSikaService();
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
      title: 'Sika Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E40AF)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SikaPage(),
    );
  }
}
