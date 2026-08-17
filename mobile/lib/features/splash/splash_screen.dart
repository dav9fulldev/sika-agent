import 'package:flutter/material.dart';
import '../../../core/constants/app_images.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _contentController;
  late AnimationController _progressController;
  late AnimationController _waveController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<double> _waveSlide;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _waveSlide = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );

    _contentController.forward();
    _progressController.forward().then((_) {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _progressController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundWaveColor = Color(0xff020614); // Identique au fond de wave.png

    return Scaffold(
      backgroundColor: backgroundWaveColor,
      body: Stack(
        children: [
          // 1. FOND UNIFORME EXACTEMENT IDENTIQUE À WAVE.PNG
          Container(
            width: double.infinity,
            height: double.infinity,
            color: backgroundWaveColor,
          ),

          // 2. LOGO ET TEXTE ANIMÉ AU CENTRE
          Center(
            child: AnimatedBuilder(
              animation: _contentController,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Image.asset(
                          AppImages.logo,
                          width: 145,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    Opacity(
                      opacity: _textFade.value,
                      child: const Column(
                        children: [
                          Text(
                            "Sika",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Your Autonomous\nFinancial Agent",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF38BDF8), // Cyan lumineux parfaitement lisible
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),

          // 3. VAGUES CYAN EN ARRIÈRE-PLAN (SANS AUCUNE DÉCOUPE NI DÉGRADÉ DIVERGENT)
          Positioned(
            bottom: 75,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _waveSlide,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _waveSlide.value * 15),
                  child: Image.asset(
                    AppImages.wave,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),

          // 4. JAUGE DE CHARGEMENT LINÉAIRE PROGRESSIVE (VERT ÉCLATANT)
          Positioned(
            bottom: 50,
            left: 85,
            right: 85,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 4,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF10B981),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
