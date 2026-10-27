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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed(
      AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
    final success = await authNotifier.registerWithEmail(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      // Le routeur de main.dart affiche l'écran suivant selon l'état d'authentification
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onGoogleRegisterPressed(AuthNotifier authNotifier) async {
    final success = await authNotifier.loginWithGoogle();
    if (success && mounted) {
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
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
                const SizedBox(height: AppSpacing.lg),

                // TITRE
                Text(
                  langNotifier.tr('Créer un compte SIKA', 'Create SIKA Account'),
                  textAlign: TextAlign.center,
                  style: AppTypography.h1.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xs),

                // SOUS-TITRE
                Text(
                  langNotifier.tr(
                    'Rejoignez le futur de la gestion financière',
                    'Join the future of financial management',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xxl),

                // SIKA SURFACE (Formulaire)
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
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fade().slideY(begin: -0.1, end: 0),

                      // CHAMP NOM
                      SikaGlassTextField(
                        controller: _nameController,
                        hintText: langNotifier.tr('Nom complet', 'Full Name'),
                        prefixIcon: Icons.person_outline,
                      ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: AppSpacing.md),

                      // CHAMP EMAIL
                      SikaGlassTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
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
                      ).animate().fade(delay: 700.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: AppSpacing.lg),

                      // BOUTON S'INSCRIRE
                      SikaPremiumButton(
                        onPressed: () => _onRegisterPressed(authNotifier, langNotifier),
                        text: langNotifier.tr('S\'inscrire', 'Sign Up'),
                        isLoading: authState.isLoading,
                      ).animate().fade(delay: 800.ms).scale(delay: 800.ms, duration: 200.ms),
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
                        onPressed: () => _onGoogleRegisterPressed(authNotifier),
                        text: langNotifier.tr('S\'inscrire avec Google', 'Sign Up with Google'),
                        isSecondary: true,
                        isLoading: authState.isLoading,
                        prefixWidget: Image.asset(
                          AppImages.googleLogo,
                          width: 24,
                        ),
                      ).animate().fade(delay: 1000.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // LIEN VERS CONNEXION (Hors de la carte)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr('Déjà un compte ? ', 'Already have an account? '),
                      style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        langNotifier.tr('Se connecter', 'Log In'),
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
