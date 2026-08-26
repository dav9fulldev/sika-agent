import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                  child: Image.asset(
                    AppImages.logo,
                    width: 90,
                  ),
                )
                    .animate()
                    .fade(duration: 600.ms)
                    .scale(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 32),
                Text(
                  langNotifier.tr('Nouveau mot de passe', 'New Password'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
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
                TextField(
                  controller: _otpController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: langNotifier.tr(
                        'Code de vérification', 'Verification code'),
                    prefixIcon: const Icon(Icons.password_outlined,
                        color: AppColors.brandSecondary),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText:
                        langNotifier.tr('Nouveau mot de passe', 'New password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.brandSecondary),
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
                  ),
                ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onResetPressed(authNotifier, langNotifier),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            langNotifier.tr('Réinitialiser', 'Reset Password')),
                  ),
                )
                    .animate()
                    .fade(delay: 700.ms)
                    .scale(delay: 700.ms, duration: 200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
