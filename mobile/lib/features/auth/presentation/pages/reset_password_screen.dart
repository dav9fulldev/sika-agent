import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/sika_surface.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';
import '../../../../core/widgets/sika_premium_button.dart';

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
          backgroundColor: AppColors.primary,
        ),
      );

      // Retour à la page de connexion
      // Le routeur de main.dart affiche l'écran suivant selon l'état d'authentification
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset(AppImages.logo, width: 80),
                ).animate().fade(duration: 600.ms).scale(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),

                // TITRE
                Text(
                  langNotifier.tr('Nouveau mot de passe', 'New Password'),
                  textAlign: TextAlign.center,
                  style: AppTypography.h1.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xs),

                // SOUS-TITRE
                Text(
                  langNotifier.tr(
                    'Entrez le code reçu et votre nouveau mot de passe.',
                    'Enter the code received and your new password.',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xxl),

                // SIKA SURFACE
                SikaSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      if (authState.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.errorSoftDark : AppColors.errorSoft,
                            borderRadius: AppSpacing.borderRadiusSm,
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: AppTypography.caption.copyWith(color: AppColors.error),
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
                      const SizedBox(height: AppSpacing.md),

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
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: AppSpacing.lg),

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
    );
  }
}
