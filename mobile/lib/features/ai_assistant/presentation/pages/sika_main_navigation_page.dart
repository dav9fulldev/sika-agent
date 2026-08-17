import 'package:flutter/material.dart';
import 'agent_hub_screen.dart';
import 'sika_chat_screen.dart';
import 'insights_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';

class SikaMainNavigationPage extends StatefulWidget {
  const SikaMainNavigationPage({super.key});

  @override
  State<SikaMainNavigationPage> createState() => _SikaMainNavigationPageState();
}

class _SikaMainNavigationPageState extends State<SikaMainNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 1. RESTRUCTURATION STRATEGIQUE DES INDEX DES PAGES POUR S'ALIGNER SUR LES ONGLETS
    final List<Widget> pages = [
      AgentHubScreen(
        onOpenChat: () => setState(() => _currentIndex = 3),     // Chat passe à l'index 3
        onOpenInsights: () => setState(() => _currentIndex = 1), // Insights reste à l'index 1
      ),
      const InsightsScreen(), // Index 1

      // LE BOUTON CENTRAL VOCAL (Index 2)
      // Note : Tu peux mettre ici l'écran d'activation vocale plein écran ou une page miroir
      AgentHubScreen(
        onOpenChat: () => setState(() => _currentIndex = 3),
        onOpenInsights: () => setState(() => _currentIndex = 1),
      ),

      const SikaChatScreen(), // Index 3 : Le Chat textuel classique
      const ProfileScreen(),  // Index 4 : Le profil (Réglages supprimé)
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      // 2. STYLISATION DE LA BARRE DE NAVIGATION (LOOK MAQUETTE BLEU NUITE)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1329), // Fond bleu nuit officiel des cartes de ta maquette
          border: Border(
            top: BorderSide(color: Colors.white10, width: 0.8), // Fine bordure supérieure
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Action spécifique si l'utilisateur clique sur le gros bouton vocal central (Index 2)
            if (index == 2) {
              // Ici, tu peux directement appeler ton service vocal au lieu de changer de page :
              // ref.read(sikaProvider.notifier).toggleListening();
              // Pour l'instant, on le laisse actif visuellement :
              setState(() => _currentIndex = index);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          backgroundColor: const Color(0xFF0B1329),
          selectedItemColor: const Color(0xFF10B981),   // Vert Sika actif de la maquette
          unselectedItemColor: const Color(0xFF475569), // Gris bleuté éteint
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            // Onglet 0
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Hub',
            ),
            // Onglet 1
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            // Onglet 2 : LE GROS BOUTON CENTRAL VOCAL ÉTIRÉ ET BRILLANT
            BottomNavigationBarItem(
              icon: CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF635BFF), // Violet Sika de ta charte
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              label: '', // Pas de texte sous le bouton central pour un effet épuré parfait
            ),
            // Onglet 3
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            // Onglet 4
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
