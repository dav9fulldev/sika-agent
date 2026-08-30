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
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';
import '../../../ai_assistant/presentation/pages/sika_main_navigation_page.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed(
      AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
    final success = await authNotifier.loginWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
        (route) => false,
      );
    }
  }

  void _onGoogleLoginPressed(AuthNotifier authNotifier) async {
    final success = await authNotifier.loginWithGoogle();
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
        (route) => false,
      );
    } else if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null &&
          authState.errorMessage!.contains('SHA-1')) {
        _showManualGoogleEmailDialog(authNotifier);
      }
    }
  }

  void _showManualGoogleEmailDialog(AuthNotifier authNotifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController emailCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dlgCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SikaSurface(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    child: Image.asset(
                      AppImages.googleLogo,
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Connexion Google',
                      style: AppTypography.h2),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Mode Développeur / Émulateur :\nSaisissez votre propre adresse Google pour vous connecter directement :',
                style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SikaGlassTextField(
                controller: emailCtrl,
                hintText: 'votre.email@gmail.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: SikaPremiumButton(
                  onPressed: () async {
                    final em = emailCtrl.text.trim();
                    if (em.isNotEmpty) {
                      Navigator.pop(dlgCtx);
                      final s = await authNotifier.loginWithGoogle(customEmail: em);
                      if (s && mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SikaMainNavigationPage()),
                          (route) => false,
                        );
                      }
                    }
                  },
                  text: 'Se connecter',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SikaPremiumButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  text: 'Annuler',
                  isSecondary: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO SIKA AVEC OMBRE (GLOW)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                        blurRadius: 48,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    AppImages.logo,
                    width: 100,
                  ),
                ).animate().fade(duration: 600.ms).scale(delay: 200.ms, duration: 400.ms),
                
                const SizedBox(height: AppSpacing.xl),

                Text(
                  langNotifier.tr('Bon retour', 'Welcome back'),
                  style: AppTypography.h1.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  langNotifier.tr(
                    'Connectez-vous à votre agent financier autonome',
                    'Log in to your autonomous financial agent',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: AppSpacing.xxl),
                
                // FORMULAIRE SIKASURFACE
                SikaSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      // ERREUR SI PRÉSENTE
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

                      // CHAMP EMAIL
                      SikaGlassTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // CHAMP MOT DE PASSE
                      SikaGlassTextField(
                        controller: _passwordController,
                        hintText: langNotifier.tr('Mot de passe', 'Password'),
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

                      // BOUTON SE CONNECTER
                      SikaPremiumButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => _onLoginPressed(authNotifier, langNotifier),
                        text: langNotifier.tr('Se connecter', 'Log In'),
                        isLoading: authState.isLoading,
                      ).animate().fade(delay: 700.ms).scale(delay: 700.ms, duration: 200.ms),

                      const SizedBox(height: AppSpacing.lg),
                      
                      // MOT DE PASSE OUBLIÉ ? (Secondary Action)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          langNotifier.tr(
                              'Mot de passe oublié ?', 'Forgot Password?'),
                          style: AppTypography.bodyMediumStrong.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ).animate().fade(delay: 800.ms),
                      
                      const SizedBox(height: AppSpacing.xl),

                      // SÉPARATEUR "OU"
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: Text(
                              langNotifier.tr('OU', 'OR'),
                              style: AppTypography.caption.copyWith(
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)),
                        ],
                      ).animate().fade(delay: 900.ms),

                      const SizedBox(height: AppSpacing.xl),

                      // BOUTON DE CONNEXION AVEC GOOGLE
                      SikaPremiumButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => _onGoogleLoginPressed(authNotifier),
                        text: langNotifier.tr('Continuer avec Google', 'Continue with Google'),
                        isSecondary: true,
                        prefixWidget: Image.asset(
                          AppImages.googleLogo,
                          width: 24,
                        ),
                      ).animate().fade(delay: 1000.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ).animate().fade(delay: 450.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: AppSpacing.xxl),

                // LIEN VERS INSCRIPTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr('Pas encore de compte ? ',
                          'Don\'t have an account? '),
                      style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: Text(
                        langNotifier.tr('S\'inscrire', 'Sign Up'),
                        style: AppTypography.bodyMediumStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ).animate().fade(delay: 1100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
