import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../ai_assistant/presentation/pages/sika_main_navigation_page.dart';

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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
        (route) => false,
      );
    }
  }

  void _onGoogleRegisterPressed(AuthNotifier authNotifier) async {
    final success = await authNotifier.loginWithGoogle();
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                const SizedBox(height: 24),

                Text(
                  langNotifier.tr(
                      'Créer un compte SIKA', 'Create SIKA Account'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  langNotifier.tr(
                    'Rejoignez le futur de la gestion financière',
                    'Join the future of financial management',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),

                // ERREUR SI PRÉSENTE
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

                // 2. CHAMP NOM
                TextField(
                  controller: _nameController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: langNotifier.tr('Nom complet', 'Full Name'),
                    prefixIcon: const Icon(Icons.person_outline,
                        color: AppColors.brandSecondary),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // 3. CHAMP EMAIL
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
                ).animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // 4. CHAMP MOT DE PASSE
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: langNotifier.tr('Mot de passe', 'Password'),
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
                ).animate().fade(delay: 700.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),

                // 5. BOUTON S'INSCRIRE
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onRegisterPressed(authNotifier, langNotifier),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(langNotifier.tr('S\'inscrire', 'Sign Up')),
                  ),
                )
                    .animate()
                    .fade(delay: 800.ms)
                    .scale(delay: 800.ms, duration: 200.ms),
                const SizedBox(height: 24),

                // SÉPARATEUR "OU"
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        langNotifier.tr('OU', 'OR'),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.2))),
                  ],
                ).animate().fade(delay: 900.ms),
                const SizedBox(height: 24),

                // 6. BOUTON DE CONNEXION AVEC GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onGoogleRegisterPressed(authNotifier),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: const Text('G',
                            style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    label: Text(
                      langNotifier.tr(
                          'S\'inscrire avec Google', 'Sign Up with Google'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ).animate().fade(delay: 1000.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),

                // 7. LIEN VERS CONNEXION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr(
                          'Déjà un compte ? ', 'Already have an account? '),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        langNotifier.tr('Se connecter', 'Log In'),
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
