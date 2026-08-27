import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';
import '../widgets/sika_voice_overlay_widget.dart';
import 'agent_hub_screen.dart';
import 'sika_chat_screen.dart';
import 'insights_screen.dart';
import '../../../profile/presentation/pages/profile_screen.dart';

class SikaMainNavigationPage extends ConsumerStatefulWidget {
  const SikaMainNavigationPage({super.key});

  @override
  ConsumerState<SikaMainNavigationPage> createState() =>
      _SikaMainNavigationPageState();
}

class _SikaMainNavigationPageState extends ConsumerState<SikaMainNavigationPage>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    final bool isListening = sikaData.state == SikaState.listening;
    final bool isProcessing = sikaData.state == SikaState.processing;

    final currentAppLang = ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.listen<SikaData>(sikaProvider, (previous, next) {
      if ((next.state == SikaState.processing ||
              next.state == SikaState.speaking) &&
          _currentIndex != 2) {
        setState(() {
          _currentIndex = 2;
        });
      }
    });

    final List<Widget> pages = [
      AgentHubScreen(
        onOpenChat: () => setState(() => _currentIndex = 2),
        onOpenInsights: () => setState(() => _currentIndex = 1),
      ),
      const InsightsScreen(),
      const SikaChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBody: true,
      body: Stack(
        children: [
          // Global background gradient to give a premium feel
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.darkBackground,
                    Color(0xFF0A0F1C),
                  ],
                ),
              ),
            ),
          ),
          IndexedStack(index: _currentIndex, children: pages),
          const SikaVoiceOverlayWidget(),
          if (_currentIndex != 2) _buildGlassNavBar(langNotifier),
          if (_currentIndex != 2)
            _buildFloatingSikaButton(
                isListening, isProcessing, currentAppLang, sikaNotifier),
        ],
      ),
    );
  }

  Widget _buildFloatingSikaButton(bool isListening, bool isProcessing,
      dynamic currentAppLang, SikaNotifier sikaNotifier) {
    return Positioned(
      bottom: 40,
      left: MediaQuery.of(context).size.width / 2 - 32,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return GestureDetector(
            onLongPressStart: (_) async {
              await sikaNotifier.startListening(
                  sttLocale: currentAppLang.sttLocale);
            },
            onLongPressEnd: (_) async {
              await sikaNotifier.stopListening();
            },
            onTap: () async {
              await sikaNotifier.toggleListening(
                  sttLocale: currentAppLang.sttLocale);
            },
            child: Transform.scale(
              scale: isListening ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isListening
                        ? [AppColors.success, const Color(0xFF059669)]
                        : [const Color(0xFFA855F7), const Color(0xFF635BFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isListening
                              ? AppColors.success
                              : const Color(0xFF635BFF))
                          .withValues(alpha: isListening ? 0.7 : 0.5),
                      blurRadius: isListening ? 30 : 20,
                      spreadRadius: isListening ? 8 : 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: isProcessing
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        isListening
                            ? Icons.mic_rounded
                            : Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: isListening ? 30 : 28,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassNavBar(LanguageNotifier langNotifier) {
    return Positioned(
      bottom: 24, // Floating offset
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
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
                    icon: Icons.grid_view_rounded,
                    activeIcon: Icons.grid_view_rounded,
                    label: 'Hub'),
                _buildNavItem(
                    index: 1,
                    icon: Icons.donut_small_rounded,
                    activeIcon: Icons.donut_small_rounded,
                    label: 'Analyse'),
                const SizedBox(width: 70), // Space for FAB
                _buildNavItem(
                    index: 2,
                    icon: Icons.forum_outlined,
                    activeIcon: Icons.forum_rounded,
                    label: 'Chat'),
                _buildNavItem(
                    index: 3,
                    icon: Icons.face_rounded,
                    activeIcon: Icons.face_rounded,
                    label: langNotifier.tr('Profil', 'Profile')),
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

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutExpo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
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
                color: isSelected ? Colors.white : AppColors.darkTextMuted,
                size: 24,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
