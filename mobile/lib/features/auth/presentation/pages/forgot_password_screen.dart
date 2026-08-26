import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSendPressed(
      AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
    final email = _emailController.text;
    final otp = await authNotifier.forgotPassword(email);

    if (otp != null && mounted) {
      // In a real app, we wouldn't receive the OTP here, we would just navigate.
      // But since we want to demonstrate it, we can show it in a snackbar for dev purposes.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code reçu (mode dev) : $otp'),
          backgroundColor: AppColors.brandPrimary,
          duration: const Duration(seconds: 5),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(email: email)),
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
                  langNotifier.tr('Mot de passe oublié ?', 'Forgot Password?'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  langNotifier.tr(
                    'Entrez votre adresse email pour recevoir un code de réinitialisation.',
                    'Enter your email address to receive a reset code.',
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
                  controller: _emailController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppColors.brandSecondary),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onSendPressed(authNotifier, langNotifier),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(langNotifier.tr('Envoyer le code', 'Send Code')),
                  ),
                )
                    .animate()
                    .fade(delay: 600.ms)
                    .scale(delay: 600.ms, duration: 200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
