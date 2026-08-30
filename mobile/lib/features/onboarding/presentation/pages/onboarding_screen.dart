import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../widgets/sika_robot_animation.dart';
import '../widgets/financial_animation.dart';
import '../widgets/security_animation.dart';

/// OnboardingScreen — Fullscreen Immersive Animated Onboarding Experience
/// Refonte V2 (Product Design)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER (Skip button could go here, but for now we keep it clean)
            const SizedBox(height: AppSpacing.lg),

            // 2. MAIN CONTENT (Carousel)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: onboardingSteps.length,
                itemBuilder: (context, index) {
                  final step = onboardingSteps[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // IMAGE / ANIMATION
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: step['widget'] as Widget,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        
                        // TEXTS
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Text(
                                step['title'] as String,
                                textAlign: TextAlign.center,
                                style: AppTypography.h1.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                step['subtitle'] as String,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. BOTTOM PANEL (Indicators & Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PAGE INDICATORS
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
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // CTA BUTTON
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
          ],
        ),
      ),
    );
  }
}
