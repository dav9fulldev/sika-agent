import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onResetPressed(
      AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
    final success = await authNotifier.resetPassword(
      widget.email,
      _otpController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langNotifier.tr(
              'Mot de passe réinitialisé avec succès !',
              'Password reset successful!')),
          backgroundColor: AppColors.brandPrimary,
        ),
      );

      // Retour à la page de connexion
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.darkBackground, AppColors.darkSurface]
                    : [const Color(0xFFF8F9FA), Colors.white],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPrimary.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(AppImages.logo, width: 90),
                    ).animate().fade(duration: 600.ms).scale(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: 32),

                    // TITRE
                    Text(
                      langNotifier.tr('Nouveau mot de passe', 'New Password'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 8),

                    // SOUS-TITRE
                    Text(
                      langNotifier.tr(
                        'Entrez le code reçu et votre nouveau mot de passe.',
                        'Enter the code received and your new password.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 40),

                    // GLASS CARD
                    SikaGlassCard(
                      child: Column(
                        children: [
                          if (authState.errorMessage != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fade().slideY(begin: -0.1, end: 0),

                          SikaGlassTextField(
                            controller: _otpController,
                            hintText: langNotifier.tr('Code de vérification', 'Verification code'),
                            prefixIcon: Icons.password_outlined,
                            keyboardType: TextInputType.number,
                          ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 16),

                          SikaGlassTextField(
                            controller: _passwordController,
                            hintText: langNotifier.tr('Nouveau mot de passe', 'New password'),
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 32),

                          SikaPremiumButton(
                            onPressed: () => _onResetPressed(authNotifier, langNotifier),
                            text: langNotifier.tr('Réinitialiser', 'Reset Password'),
                            isLoading: authState.isLoading,
                          ).animate().fade(delay: 700.ms).scale(delay: 700.ms, duration: 200.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
