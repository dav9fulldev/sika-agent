import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xff020614), // Fond bleu nuit officiel de la maquette
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
                  Color(0x0a3f8cff), // Halo bleu très discret et diffus
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 2. CONTENU DU PAGE VIEW AVEC VOS TRANSITIONS DE FONDU PARALLAXE
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
                            value = (1 - (value.abs() * 0.4)).clamp(0.0, 1.0);
                          }

                          return Opacity(
                            opacity: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 16.0,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 30),

                                  // TITRE DE L'ÉTAPE
                                  Text(
                                    step['title'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // SOUS-TITRE DE L'ÉTAPE
                                  Text(
                                    step['subtitle'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xff94a3b8), // Gris bleuté ultra-lisible
                                      fontSize: 15,
                                      height: 1.45,
                                    ),
                                  ),

                                  const Spacer(),

                                  // COMPOSANT ANIMÉ DÉDIÉ (ROBOT, ECOSYSTEME, CADENAS)
                                  step['widget'] as Widget,

                                  const Spacer(flex: 2),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 3. INDICATEURS DE PAGE (POINTS HORIZONTAUX MODÈLE MAQUETTE)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingSteps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8, // Effet d'étirement moderne
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? const Color(0xff3f8cff) // Bleu brillant maquette
                            : const Color(0xff1e293b), // Point inactif sombre
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 4. MAIN ACTION BUTTON (SUIVANT / COMMENCER EN DEGRADÉ MAQUETTE)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: GestureDetector(
                    onTap: () {
                      if (_currentPage < _onboardingSteps.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        widget.onFinish();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56, // Épaisseur professionnelle
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xff3f8cff), // Bleu brillant
                            Color(0xff635bff), // Violet Sika
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff635bff).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage == _onboardingSteps.length - 1
                              ? 'Commencer'
                              : 'Suivant',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
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
