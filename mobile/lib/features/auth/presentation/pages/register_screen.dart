import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _onRegisterPressed(AuthNotifier authNotifier, LanguageNotifier langNotifier) async {
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
      backgroundColor: const Color(0xff020614),
      appBar: AppBar(
        backgroundColor: const Color(0xff020614),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                // 1. LOGO SIKA
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    AppImages.logo,
                    width: 90,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  langNotifier.tr('Créer un compte SIKA', 'Create SIKA Account'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  langNotifier.tr(
                    'Rejoignez la révolution de l\'agent financier autonome',
                    'Join the autonomous financial agent revolution',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),

                // ERREUR SI PRÉSENTE
                if (authState.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 13),
                    ),
                  ),

                // 2. CHAMP NOM COMPLET
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1329),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: langNotifier.tr('Nom complet', 'Full Name'),
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.cyan, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. CHAMP EMAIL
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1329),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Color(0xFF475569)),
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.cyan, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. CHAMP MOT DE PASSE
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1329),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: langNotifier.tr('Créer un mot de passe', 'Create a Password'),
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.cyan, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. BOUTON CRÉER COMPTE
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onRegisterPressed(authNotifier, langNotifier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            langNotifier.tr('Créer mon compte', 'Create Account'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // SÉPARATEUR
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF1E293B))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        langNotifier.tr('OU', 'OR'),
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF1E293B))),
                  ],
                ),
                const SizedBox(height: 20),

                // 6. BOUTON GOOGLE SIGN-UP
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading ? null : () => _onGoogleRegisterPressed(authNotifier),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    label: Text(
                      langNotifier.tr('S\'inscrire avec Google', 'Sign Up with Google'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B1329),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 7. LIEN RETOUR CONNEXION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr('Déjà un compte ? ', 'Already have an account? '),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        langNotifier.tr('Se connecter', 'Log In'),
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
