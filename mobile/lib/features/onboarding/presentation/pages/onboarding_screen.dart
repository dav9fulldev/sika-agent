import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../widgets/sika_robot_animation.dart';
import '../widgets/financial_animation.dart';
import '../widgets/security_animation.dart';

/// OnboardingScreen — Modern, Premium Animated 3-Step Onboarding Experience
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingSteps = [
    {
      'title': 'Bienvenue chez Sika 👋',
      'subtitle':
          'Votre agent financier autonome qui vous accompagne au quotidien.',
      'widget': const SikaRobotAnimation(),
    },
    {
      'title': 'Sika comprend vos finances',
      'subtitle':
          'Il analyse vos transactions, comprend votre contexte et anticipe les risques.',
      'widget': const FinancialAnimation(),
    },
    {
      'title': 'Toujours sous votre contrôle',
      'subtitle':
          'Sika agit avec votre autorisation pour toutes les actions sensibles.',
      'widget': const SecurityAnimation(),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // SIKA BRAND HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppImages.sikaLogo,
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.auto_awesome,
                    color: AppColors.cyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sika',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // PAGE VIEW WITH FLUID SLIDE & FADE
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _onboardingSteps.length,
                itemBuilder: (context, index) {
                  final step = _onboardingSteps[index];

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page ?? 0) - index;
                        value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                      }

                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.9 + (value * 0.1),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // TITLE
                                Text(
                                  step['title'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // SUBTITLE
                                Text(
                                  step['subtitle'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ANIMATED HERO VISUAL
                                step['widget'] as Widget,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // PAGE INDICATOR DOTS (● ○ ○, ○ ● ○, ○ ○ ●)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingSteps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.indigo
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // MAIN BUTTON (SUIVANT / COMMENCER)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _onboardingSteps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      widget.onFinish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: AppColors.white,
                    elevation: 6,
                    shadowColor: AppColors.indigo.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _onboardingSteps.length - 1
                        ? 'Commencer'
                        : 'Suivant',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
