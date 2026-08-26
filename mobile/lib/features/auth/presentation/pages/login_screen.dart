import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
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

  void _onLoginPressed(AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
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
      if (authState.errorMessage != null && authState.errorMessage!.contains('SHA-1')) {
        _showManualGoogleEmailDialog(authNotifier);
      }
    }
  }

  void _showManualGoogleEmailDialog(AuthNotifier authNotifier) {
    final TextEditingController emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.onSurface),
              child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text('Connexion Google', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode Développeur / Émulateur :\nSaisissez votre propre adresse Google pour vous connecter directement :',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'votre.email@gmail.com',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              final em = emailCtrl.text.trim();
              if (em.isNotEmpty) {
                Navigator.pop(dlgCtx);
                final s = await authNotifier.loginWithGoogle(customEmail: em);
                if (s && mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
                    (route) => false,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: Text('Se connecter', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO SIKA AVEC OMBRE
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
                    width: 110,
                  ),
                ).animate().fade(duration: 600.ms).scale(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 32),

                Text(
                  langNotifier.tr('Connexion SIKA', 'SIKA Login'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 8),
                
                Text(
                  langNotifier.tr(
                    'Accédez à votre assistant financier autonome',
                    'Access your autonomous financial agent',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 40),

                // ERREUR SI PRÉSENTE
                if (authState.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade().slideY(begin: -0.1, end: 0),

                // 2. CHAMP EMAIL
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.brandSecondary),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 16),

                // 3. CHAMP MOT DE PASSE
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: langNotifier.tr('Mot de passe', 'Password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.brandSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 16),

                // MOT DE PASSE OUBLIÉ ?
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      langNotifier.tr('Mot de passe oublié ?', 'Forgot Password?'),
                      style: const TextStyle(
                        color: AppColors.brandSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ).animate().fade(delay: 700.ms),
                
                const SizedBox(height: 32),

                // 4. BOUTON SE CONNECTER
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onLoginPressed(authNotifier, langNotifier),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(langNotifier.tr('Se connecter', 'Log In')),
                  ),
                ).animate().fade(delay: 800.ms).scale(delay: 800.ms, duration: 200.ms),
                
                const SizedBox(height: 24),

                // SÉPARATEUR "OU"
                Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        langNotifier.tr('OU', 'OR'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), 
                          fontSize: 12, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
                  ],
                ).animate().fade(delay: 900.ms),
                
                const SizedBox(height: 24),

                // 5. BOUTON DE CONNEXION AVEC GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading ? null : () => _onGoogleLoginPressed(authNotifier),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    label: Text(
                      langNotifier.tr('Continuer avec Google', 'Continue with Google'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ).animate().fade(delay: 1000.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 32),

                // 6. LIEN VERS INSCRIPTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr('Pas encore de compte ? ', 'Don\'t have an account? '),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: Text(
                        langNotifier.tr('S\'inscrire', 'Sign Up'),
                        style: const TextStyle(
                          color: AppColors.brandPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
