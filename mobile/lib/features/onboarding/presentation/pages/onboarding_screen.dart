import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../widgets/sika_robot_animation.dart';
import '../widgets/financial_animation.dart';
import '../widgets/security_animation.dart';

/// OnboardingScreen — Fullscreen Immersive Animated Onboarding Experience
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
      'image': AppImages.bienv,
    },
    {
      'title': 'Sika comprend vos finances',
      'subtitle':
          'Il analyse vos transactions, comprend votre contexte et anticipe les risques.',
      'widget': const FinancialAnimation(),
      'image': AppImages.bienv,
    },
    {
      'title': 'Toujours sous votre contrôle',
      'subtitle':
          'Sika agit avec votre autorisation pour toutes les actions sensibles.',
      'widget': const SecurityAnimation(),
      'image': AppImages.bienv,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FULLSCREEN BACKGROUND IMAGE TAKING THE ENTIRE SCREEN
          Image.asset(
            AppImages.bienv,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.background,
            ),
          ),

          // 2. DARK GRADIENT OVERLAY FOR CRISP TEXT READABILITY
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.85),
                  AppColors.background.withValues(alpha: 0.4),
                  AppColors.background.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. PAGE VIEW CONTENT (TOP TEXT OVERLAY + CENTER ANIMATIONS)
          SafeArea(
            child: Column(
              children: [
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 16.0),
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),

                                  // TOP TEXT DIRECTLY OVERLAID ON IMAGE
                                  Text(
                                    step['title'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    step['subtitle'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      height: 1.4,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // CENTER ANIMATED HERO VISUAL
                                  step['widget'] as Widget,

                                  const Spacer(),
                                ],
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

                const SizedBox(height: 20),

                // MAIN BUTTON (SUIVANT / COMMENCER)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        ],
      ),
    );
  }
}
