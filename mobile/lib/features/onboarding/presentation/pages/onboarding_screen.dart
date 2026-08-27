import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../widgets/sika_robot_animation.dart';
import '../widgets/financial_animation.dart';
import '../widgets/security_animation.dart';

/// OnboardingScreen — Fullscreen Immersive Animated Onboarding Experience
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final List<Map<String, dynamic>> onboardingSteps = [
      {
        'title':
            langNotifier.tr('Bienvenue chez Sika 👋', 'Welcome to Sika 👋'),
        'subtitle': langNotifier.tr(
          'Votre agent financier autonome qui vous accompagne au quotidien.',
          'Your autonomous financial agent accompanying you daily.',
        ),
        'widget': const SikaRobotAnimation(),
      },
      {
        'title': langNotifier.tr(
            'Sika comprend vos finances', 'Sika understands your finances'),
        'subtitle': langNotifier.tr(
          'Il analyse vos transactions, comprend votre contexte et anticipe les risques.',
          'It analyzes your transactions, understands your context, and anticipates risks.',
        ),
        'widget': const FinancialAnimation(),
      },
      {
        'title': langNotifier.tr(
            'Toujours sous votre contrôle', 'Always under your control'),
        'subtitle': langNotifier.tr(
          'Sika agit avec votre autorisation pour toutes les actions sensibles.',
          'Sika acts with your permission for all sensitive actions.',
        ),
        'widget': const SecurityAnimation(),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. HALO D'AMBIANCE DE FOND
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.3),
                radius: 1.2,
                colors: [
                  Color(0x0a3f8cff),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 2. CONTENU PRINCIPAL
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: onboardingSteps.length,
                    itemBuilder: (context, index) {
                      final step = onboardingSteps[index];

                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = (_pageController.page ?? 0) - index;
                            value = (1 - (value.abs() * 0.4)).clamp(0.0, 1.0);
                          }

                          return Opacity(
                            opacity: value,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: step['widget'] as Widget,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 3. PANNEAU INFÉRIEUR EN VERRE
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SikaGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TITRE
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            onboardingSteps[_currentPage]['title'] as String,
                            key: ValueKey<String>(onboardingSteps[_currentPage]['title'] as String),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // SOUS-TITRE
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            onboardingSteps[_currentPage]['subtitle'] as String,
                            key: ValueKey<String>(onboardingSteps[_currentPage]['subtitle'] as String),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: const Color(0xff94a3b8),
                                  height: 1.45,
                                ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // INDICATEURS DE PAGE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            onboardingSteps.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? AppColors.brandPrimary
                                    : AppColors.brandPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // BOUTON ACTION
                        SikaPremiumButton(
                          onPressed: () {
                            if (_currentPage < onboardingSteps.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            } else {
                              widget.onFinish();
                            }
                          },
                          text: _currentPage == onboardingSteps.length - 1
                              ? langNotifier.tr('Commencer', 'Get Started')
                              : langNotifier.tr('Suivant', 'Next'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
