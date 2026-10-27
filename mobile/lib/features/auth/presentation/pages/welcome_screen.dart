import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_images.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../../../paypal/presentation/widgets/sika_pay_ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Connexion Google ; sur émulateur sans empreinte SHA-1 enregistrée, propose la saisie manuelle de l'adresse.
Future<void> signInWithGoogle(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(authProvider.notifier);
  final ok = await notifier.loginWithGoogle();
  if (!context.mounted) return;
  if (ok) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  } else if (ref.read(authProvider).errorMessage?.contains('SHA-1') ?? false) {
    final lang = ref.read(languageProvider.notifier);
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(lang.tr('Connexion Google', 'Google sign-in'), style: const TextStyle(color: SikaBrand.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            lang.tr('Mode émulateur : saisissez votre adresse Google pour vous connecter.',
                'Emulator mode: enter your Google address to sign in.'),
            style: const TextStyle(color: SikaBrand.muted),
          ),
          const SizedBox(height: 16),
          SikaField(controller: ctrl, label: 'votre.email@gmail.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: Text(lang.tr('Annuler', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dlg);
              await notifier.loginWithGoogle(customEmail: email);
            },
            child: Text(lang.tr('Se connecter', 'Sign in')),
          ),
        ],
      ),
    );
  }
}

/// Étape 2 — Bienvenue : connexion par e-mail, puis Google ou PayPal en alternative.
/// Après succès, le routeur de `main.dart` affiche l'étape suivante.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _rememberedEmailKey = 'sika_remembered_email';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final email = prefs.getString(_rememberedEmailKey);
      if (email != null && mounted) {
        setState(() {
          _emailController.text = email;
          _rememberMe = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _socialPending = false;

  Future<void> _onPayPal() async {
    setState(() => _socialPending = true);
    await ref.read(authProvider.notifier).loginWithPayPal();
    if (mounted) setState(() => _socialPending = false);
  }

  Future<void> _saveRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authProvider.notifier).loginWithEmail(_emailController.text, _passwordController.text);
    if (ok) {
      await _saveRememberedEmail();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final auth = ref.watch(authProvider);

    return SikaEntryScaffold(
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 44),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SikaPayLogo(size: 44),
            SizedBox(width: 10),
            SikaPayWordmark(fontSize: 28),
          ]),
          const SizedBox(height: 36),
          Text(
            lang.tr('Bienvenue sur SIKA Pay', 'Welcome to SIKA Pay'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SikaBrand.ink, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            lang.tr('Accédez à votre compte pour continuer.', 'Access your account to continue.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SikaBrand.muted, fontSize: 14.5),
          ),
          const SizedBox(height: 28),
          SikaField(
            controller: _emailController,
            label: lang.tr('Adresse email', 'Email address'),
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 14),
          SikaField(
            controller: _passwordController,
            label: lang.tr('Mot de passe', 'Password'),
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _onLogin(),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: SikaBrand.action,
                    side: const BorderSide(color: SikaBrand.line, width: 1.5),
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                  Flexible(
                    child: Text(lang.tr('Se souvenir de moi', 'Remember me'),
                        style: const TextStyle(color: SikaBrand.ink, fontSize: 13.5)),
                  ),
                ]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              child: Text(lang.tr('Mot de passe oublié ?', 'Forgot password?'),
                  style: const TextStyle(color: SikaBrand.action, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (!auth.isLoading && auth.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(auth.errorMessage!, style: const TextStyle(color: SikaBrand.danger, fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          SikaPrimaryButton(label: lang.tr('Se connecter', 'Sign in'), loading: auth.isLoading && !_socialPending, onPressed: _onLogin),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(lang.tr('Pas encore de compte ?', 'No account yet?'), style: const TextStyle(color: SikaBrand.muted, fontSize: 14)),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: Text(lang.tr('Créer un compte', 'Create an account'),
                  style: const TextStyle(color: SikaBrand.action, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Divider(color: SikaBrand.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(lang.tr('Ou continuer avec', 'Or continue with'), style: const TextStyle(color: SikaBrand.muted, fontSize: 13.5)),
            ),
            const Expanded(child: Divider(color: SikaBrand.line)),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: _SocialPill(
                label: 'Google',
                logo: Image.asset(AppImages.googleLogo, width: 20, height: 20),
                onTap: auth.isLoading ? null : () => signInWithGoogle(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialPill(
                label: 'PayPal',
                logo: const Icon(Icons.account_balance_wallet_rounded, color: SikaPayColors.paypalNavy, size: 20),
                onTap: auth.isLoading ? null : _onPayPal,
              ),
            ),
          ]),
          if (_socialPending && auth.isLoading) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SikaBrand.action)),
              const SizedBox(width: 10),
              Text(lang.tr('Connexion PayPal en cours…', 'Signing in with PayPal…'), style: const TextStyle(color: SikaBrand.muted)),
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).cancelPayPalLogin(),
                child: Text(lang.tr('Annuler', 'Cancel'), style: const TextStyle(color: SikaBrand.action, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          Text(
            lang.tr('PayPal : environnement de test (sandbox), aucun argent réel.', 'PayPal: test environment (sandbox), no real money.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SikaBrand.muted, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

/// Bouton compact « logo + nom » des connexions tierces.
class _SocialPill extends StatelessWidget {
  final String label;
  final Widget logo;
  final VoidCallback? onTap;
  const _SocialPill({required this.label, required this.logo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: SikaBrand.ink,
          side: const BorderSide(color: SikaBrand.line, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [logo, const SizedBox(width: 10), Text(label)]),
      ),
    );
  }
}
