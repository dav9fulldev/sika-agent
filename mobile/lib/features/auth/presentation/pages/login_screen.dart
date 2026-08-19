import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../ai_assistant/presentation/pages/sika_main_navigation_page.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(text: 'david.yao@email.com');
  final TextEditingController _passwordController = TextEditingController(text: '••••••••');
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

  void _showGoogleAccountPicker(AuthNotifier authNotifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1329),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        final TextEditingController customEmailController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Se connecter avec Google',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Choisissez un compte Google pour continuer sur SIKA',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 12),

              // COMPTE 1
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF38BDF8),
                  child: Text('DY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('David YAO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('david.yao@gmail.com', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                onTap: () async {
                  Navigator.pop(modalCtx);
                  final success = await authNotifier.loginWithGoogle(
                    email: "david.yao@gmail.com",
                    name: "David YAO",
                  );
                  if (success && mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
                      (route) => false,
                    );
                  }
                },
              ),
              const Divider(color: Color(0xFF1E293B), height: 1),

              // COMPTE 2
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Text('DK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('David KOUADIO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('david.kouadio@gmail.com', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                onTap: () async {
                  Navigator.pop(modalCtx);
                  final success = await authNotifier.loginWithGoogle(
                    email: "david.kouadio@gmail.com",
                    name: "David KOUADIO",
                  );
                  if (success && mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
                      (route) => false,
                    );
                  }
                },
              ),
              const Divider(color: Color(0xFF1E293B), height: 1),

              // COMPTE PERSONNALISÉ
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.cyan, size: 20),
                ),
                title: const Text('Utiliser un autre compte Google', style: TextStyle(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  showDialog(
                    context: modalCtx,
                    builder: (dlgCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF0B1329),
                      title: const Text('Autre compte Google', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: TextField(
                        controller: customEmailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'adresse@gmail.com',
                          hintStyle: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dlgCtx),
                          child: const Text('Annuler', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final email = customEmailController.text.trim();
                            if (email.isNotEmpty) {
                              Navigator.pop(dlgCtx);
                              Navigator.pop(modalCtx);
                              final name = email.split('@').first;
                              final success = await authNotifier.loginWithGoogle(
                                email: email,
                                name: name[0].toUpperCase() + name.substring(1),
                              );
                              if (success && mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SikaMainNavigationPage()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          child: const Text('Continuer'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onGoogleLoginPressed(AuthNotifier authNotifier) {
    _showGoogleAccountPicker(authNotifier);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xff020614),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO SIKA AVEC OMBRE CYAN
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
                    width: 100,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  langNotifier.tr('Connexion SIKA', 'SIKA Login'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  langNotifier.tr(
                    'Accédez à votre assistant financier autonome',
                    'Access your autonomous financial agent',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),

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

                // 2. CHAMP EMAIL
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
                const SizedBox(height: 16),

                // 3. CHAMP MOT DE PASSE
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
                      hintText: langNotifier.tr('Mot de passe', 'Password'),
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

                // 4. BOUTON SE CONNECTER (VERT ÉMERAUDE)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => _onLoginPressed(authNotifier, langNotifier),
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
                            langNotifier.tr('Se connecter', 'Log In'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // SÉPARATEUR "OU"
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

                // 5. BOUTON DE CONNEXION AVEC GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading ? null : () => _onGoogleLoginPressed(authNotifier),
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
                      langNotifier.tr('Continuer avec Google', 'Continue with Google'),
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
                const SizedBox(height: 30),

                // 6. LIEN VERS INSCRIPTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      langNotifier.tr('Pas encore de compte ? ', 'Don\'t have an account? '),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
