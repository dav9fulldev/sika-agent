import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';
import '../widgets/sika_voice_overlay_widget.dart';
import 'agent_hub_screen.dart';
import 'sika_chat_screen.dart';
import 'insights_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';

/// SikaMainNavigationPage — Main navigation scaffold with 4 aligned screens,
/// a Siri-style voice listening overlay, and an interactive central voice button.
class SikaMainNavigationPage extends ConsumerStatefulWidget {
  const SikaMainNavigationPage({super.key});

  @override
  ConsumerState<SikaMainNavigationPage> createState() =>
      _SikaMainNavigationPageState();
}

class _SikaMainNavigationPageState
    extends ConsumerState<SikaMainNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    final bool isListening = sikaData.state == SikaState.listening;

    final currentAppLang = ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    // ÉCOUTEUR DE REDIRECTION AUTOMATIQUE VERS CHAT EN CAS DE TRAITEMENT VOCAL
    ref.listen<SikaData>(sikaProvider, (previous, next) {
      if ((next.state == SikaState.processing || next.state == SikaState.speaking) &&
          _currentIndex != 2) {
        setState(() {
          _currentIndex = 2; // Auto-redirection vers l'onglet Chat (Index 2)
        });
      }
    });

    // 4 ÉCRANS RÉELS ALIGNÉS SUR LES ONGLETS DE NAVIGATION
    final List<Widget> pages = [
      AgentHubScreen(
        onOpenChat: () => setState(() => _currentIndex = 2),     // Chat à l'Index 2
        onOpenInsights: () => setState(() => _currentIndex = 1), // Insights à l'Index 1
      ),
      const InsightsScreen(), // Index 1
      const SikaChatScreen(), // Index 2
      const ProfileScreen(),  // Index 3
    ];

    return Scaffold(
      backgroundColor: const Color(0xff020614),
      body: Stack(
        children: [
          // 1. NAVIGATION PRINCIPALE (INDEXED STACK)
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // 2. OVERLAY GLOBAL STYLE SIRI ("Sika écoute...")
          const SikaVoiceOverlayWidget(),
        ],
      ),

      // 3. BOUTON CENTRAL VOCAL INTERACTIF SURÉLEVÉ (HOLD-TO-TALK & INTERACTIF)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _currentIndex == 2 ? null : GestureDetector(
        onLongPressStart: (_) async {
          debugPrint('[VOICE NAV] Hold-to-Talk STARTED');
          await sikaNotifier.startListening(sttLocale: currentAppLang.sttLocale);
        },
        onLongPressEnd: (_) async {
          debugPrint('[VOICE NAV] Hold-to-Talk ENDED');
          await sikaNotifier.stopListening();
        },
        onTap: () async {
          debugPrint('[VOICE NAV] Voice button tapped');
          await sikaNotifier.toggleListening(sttLocale: currentAppLang.sttLocale);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isListening ? 64 : 56,
          height: isListening ? 64 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF635BFF), // Violet Sika officiel (#635BFF)
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF635BFF).withValues(
                  alpha: isListening ? 0.8 : 0.45,
                ),
                blurRadius: isListening ? 20 : 12,
                spreadRadius: isListening ? 6 : 2,
              ),
              if (isListening)
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                  blurRadius: 28,
                  spreadRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: Icon(
              isListening ? Icons.mic_rounded : Icons.auto_awesome,
              color: Colors.white,
              size: isListening ? 30 : 24,
            ),
          ),
        ),
      ),

      // 4. BARRE DE NAVIGATION MAQUETTE BLEU NUIT (#0B1329) AVEC BORDURE ULTRA-FINE
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1329),
          border: Border(
            top: BorderSide(
              color: Colors.white10,
              width: 0.8,
            ),
          ),
        ),
        child: BottomAppBar(
          color: const Color(0xFF0B1329),
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ONGLET 0 : HUB
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Hub',
                ),

                // ONGLET 1 : INSIGHTS
                _buildNavItem(
                  index: 1,
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights,
                  label: 'Insights',
                ),

                // ESPACE RÉSERVÉ POUR LE BOUTON CENTRAL FLOATING
                const SizedBox(width: 48),

                // ONGLET 2 : CHAT
                _buildNavItem(
                  index: 2,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                ),

                // ONGLET 3 : PROFIL
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: langNotifier.tr('Profil', 'Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;
    const Color activeColor = Color(0xFF10B981);   // Vert Sika actif maquette
    const Color inactiveColor = Color(0xFF475569); // Gris bleuté éteint

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
