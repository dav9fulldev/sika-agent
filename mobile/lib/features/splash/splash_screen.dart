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
  int activeDot = 0;
  Timer? dotTimer;

  @override
  void initState() {
    super.initState();

    dotTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (timer) {
        if (mounted) {
          setState(() {
            activeDot = (activeDot + 1) % 3;
          });
        }
      },
    );

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
  void dispose() {
    dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.background,
                  AppColors.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppImages.logo,
                  width: 125,
                  gaplessPlayback: true,
                ),

                const SizedBox(height: 25),

                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: "Sika ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: "Assistant",
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Your Autonomous Financial Agent",
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: -75,
            left: 0,
            right: 0,
            child: Image.asset(
              AppImages.wave,
              gaplessPlayback: true,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                dot(0),
                const SizedBox(width: 8),
                dot(1),
                const SizedBox(width: 8),
                dot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget dot(int index) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: activeDot == index ? AppColors.cyan : Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}