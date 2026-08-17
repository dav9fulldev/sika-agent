import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    precacheImage(
      const AssetImage(AppImages.logo),
      context,
    );

    precacheImage(
      const AssetImage(AppImages.wave),
      context,
    );
  }

  Future<void> checkSession() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.background,
          ),

          // 2. LOGO — POSITION HAUTE (TIERS SUPÉRIEUR)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.16,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                AppImages.logo,
                width: 130,
                gaplessPlayback: true,
              ),
            ),
          ),

          // 3. WAVE — PARTIE BASSE
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              AppImages.wave,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}
