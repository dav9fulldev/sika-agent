import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // FULL SPLASH IMAGE FROM USER ASSETS (assets/images/splash.png)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Image.asset(
                    AppImages.splash,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          AppImages.sikaLogo,
                          width: 120,
                          height: 120,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Sika',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your Autonomous Financial Agent',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // BOTTOM LOADING BAR & SUBTITLE TEXT (TRAIT DE CHARGEMENT)
              Positioned(
                bottom: 40,
                left: 40,
                right: 40,
                child: Column(
                  children: [
                    // GLOWING PROGRESS BAR (TRAIT DE CHARGEMENT)
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.cyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Autonomous Financial Agent',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
