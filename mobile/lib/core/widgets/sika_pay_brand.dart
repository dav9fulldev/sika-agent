import 'package:flutter/material.dart';

import '../constants/app_images.dart';

/// Jetons de marque SIKA Pay, dérivés du logo (cyan + bleu roi) et des maquettes.
class SikaBrand {
  SikaBrand._();

  static const Color royal = Color(0xFF0A3BB5); // moitié basse du logo
  static const Color cyan = Color(0xFF06C1E0); // moitié haute du logo
  static const Color action = Color(0xFF1463FF); // boutons d'action
  static const Color ink = Color(0xFF0D1B3E); // texte principal
  static const Color muted = Color(0xFF5B6886); // texte secondaire
  static const Color mist = Color(0xFFF4F7FD); // fonds clairs
  static const Color line = Color(0xFFE2E8F4); // contours de champs
  static const Color danger = Color(0xFFD92D45);
}

/// Logo « S » officiel.
class SikaPayLogo extends StatelessWidget {
  final double size;
  const SikaPayLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset(AppImages.sikaMark, width: size, height: size, semanticLabel: 'SIKA Pay');
  }
}

/// Mot-symbole « SIKA Pay » tel que sur les maquettes.
class SikaPayWordmark extends StatelessWidget {
  final double fontSize;
  const SikaPayWordmark({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'SIKA ', style: base.copyWith(color: SikaBrand.ink)),
        TextSpan(text: 'Pay', style: base.copyWith(color: SikaBrand.action, fontWeight: FontWeight.w700)),
      ]),
      semanticsLabel: 'SIKA Pay',
    );
  }
}

class SikaPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const SikaPrimaryButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: SikaBrand.action,
          disabledBackgroundColor: SikaBrand.action.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

class SikaOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  const SikaOutlineButton({super.key, required this.label, this.onPressed, this.leading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: SikaBrand.action,
          side: const BorderSide(color: SikaBrand.action, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Text(label),
        ]),
      ),
    );
  }
}

/// Champ de formulaire clair avec icône et libellé flottant.
class SikaField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  const SikaField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  @override
  State<SikaField> createState() => _SikaFieldState();
}

class _SikaFieldState extends State<SikaField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(color: SikaBrand.ink, fontSize: 15.5, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: SikaBrand.muted, fontSize: 14.5),
        floatingLabelStyle: const TextStyle(color: SikaBrand.action, fontWeight: FontWeight.w600),
        prefixIcon: Icon(widget.icon, color: SikaBrand.muted, size: 21),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Afficher' : 'Masquer',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: SikaBrand.muted, size: 21),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: border(SikaBrand.line),
        focusedBorder: border(SikaBrand.action, 1.6),
      ),
    );
  }
}

/// Écran clair commun aux étapes d'entrée (indépendant du thème sombre).
class SikaEntryScaffold extends StatelessWidget {
  final Widget child;
  final Widget? top;
  const SikaEntryScaffold({super.key, required this.child, this.top});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: Theme.of(context).colorScheme.copyWith(brightness: Brightness.light, primary: SikaBrand.action, onSurface: SikaBrand.ink),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            if (top != null) top!,
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight - 36), child: child),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
