import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../../providers/sika_provider.dart';
import '../widgets/sika_voice_overlay_widget.dart';
import 'sika_chat_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_home_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_history_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';

class SikaMainNavigationPage extends ConsumerStatefulWidget {
  const SikaMainNavigationPage({super.key});

  @override
  ConsumerState<SikaMainNavigationPage> createState() =>
      _SikaMainNavigationPageState();
}

class _SikaMainNavigationPageState extends ConsumerState<SikaMainNavigationPage>
{
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    final bool isListening = sikaData.state == SikaState.listening;
    final bool isProcessing = sikaData.state == SikaState.processing;

    final currentAppLang = ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.listen<SikaData>(sikaProvider, (previous, next) {
      if (next.voiceLive) {
        // Conversation vocale : on reste sur l'écran courant, sauf pour montrer une carte à confirmer
        final newCard = next.messages.length != (previous?.messages.length ?? 0) &&
            next.messages.isNotEmpty &&
            next.messages.last.suggestedTransaction != null;
        if (newCard && _currentIndex != 2) setState(() => _currentIndex = 2);
        return;
      }
      if ((next.state == SikaState.processing ||
              next.state == SikaState.speaking) &&
          _currentIndex != 2) {
        setState(() {
          _currentIndex = 2;
        });
      }
    });

    final List<Widget> pages = [
      SikaPayHomeScreen(
        onOpenChat: () => setState(() => _currentIndex = 2),
        onOpenHistory: () => setState(() => _currentIndex = 1),
        onOpenProfile: () => setState(() => _currentIndex = 3),
      ),
      const SikaPayHistoryScreen(),
      SikaChatScreen(
        onBackPressed: () => setState(() => _currentIndex = 0),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: pages),
          if (_currentIndex != 2)
            _buildPremiumNavBar(langNotifier, isListening, isProcessing, currentAppLang, sikaNotifier),
          const SikaVoiceOverlayWidget(),
        ],
      ),
    );
  }

  Widget _buildPremiumNavBar(LanguageNotifier langNotifier, bool isListening, bool isProcessing, AppLanguage currentAppLang, SikaNotifier sikaNotifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 24, // Floating offset
      left: 20,
      right: 20,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: langNotifier.tr('Accueil', 'Home')),
            _buildNavItem(
                index: 2,
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum_rounded,
                label: langNotifier.tr('Assistant', 'Assistant')),

            // Central SIKA AI Button
            _buildCentralSikaButton(isListening, isProcessing, currentAppLang, sikaNotifier),

            _buildNavItem(
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: langNotifier.tr('Transactions', 'Transactions')),
            _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: langNotifier.tr('Profil', 'Profile')),
          ],
        ),
      ),
    );
  }

  /// Bouton vocal central : bleu SIKA, micro. Écoute : halo cyan qui suit le niveau réel du micro.
  /// Réflexion : arc qui tourne. Réponse vocale : carré d'arrêt (interrompt SIKA).
  Widget _buildCentralSikaButton(bool isListening, bool isProcessing, AppLanguage currentAppLang, SikaNotifier sikaNotifier) {
    final data = ref.watch(sikaProvider);
    final isSpeaking = data.state == SikaState.speaking;
    final langNotifier = ref.read(languageProvider.notifier);
    final halo = isListening ? 1.0 + data.soundLevel * 0.45 : 1.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: isSpeaking
          ? langNotifier.tr('Arrêter SIKA', 'Stop SIKA')
          : data.voiceLive
              ? langNotifier.tr('Terminer la conversation', 'End conversation')
              : isListening
                  ? langNotifier.tr('Envoyer', 'Send')
                  : langNotifier.tr('Parler à SIKA', 'Talk to SIKA'),
      child: GestureDetector(
        onTap: () async {
          if (isSpeaking) {
            await sikaNotifier.stopSpeaking(resetState: true);
          } else if (data.voiceLive) {
            await sikaNotifier.stopLiveVoice();
          } else if (!isProcessing) {
            await sikaNotifier.toggleListening(sttLocale: currentAppLang.sttLocale);
          }
        },
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            // Halo du niveau sonore
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: 56 * halo,
              height: 56 * halo,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? SikaBrand.cyan.withValues(alpha: 0.28) : Colors.transparent,
              ),
            ),
            if (isProcessing)
              const SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: SikaBrand.cyan, strokeCap: StrokeCap.round),
              ),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSpeaking ? SikaBrand.ink : SikaBrand.action,
                border: Border.all(color: isDark ? AppColors.darkSurface : Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: SikaBrand.action.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
                ],
              ),
              child: Icon(
                isSpeaking ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ]),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : AppColors.brandPrimary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutExpo,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
