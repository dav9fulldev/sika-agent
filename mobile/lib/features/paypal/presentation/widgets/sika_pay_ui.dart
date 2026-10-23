import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';

/// Palette SIKA Pay (bleu PayPal pour les actions de paiement, indigo SIKA pour l'agent).
class SikaPayColors {
  SikaPayColors._();
  static const Color paypalBlue = Color(0xFF0070E0);
  static const Color paypalNavy = Color(0xFF003087);
  static const Color heroStart = Color(0xFF2563EB);
  static const Color heroEnd = Color(0xFF6D5BFF);
}

/// Pastille "SANDBOX · TEST" : rappelle en permanence qu'aucun argent réel ne bouge.
class SandboxBadge extends StatelessWidget {
  final bool compact;
  const SandboxBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact ? 'SANDBOX' : 'SANDBOX · TEST MODE',
        style: const TextStyle(color: Color(0xFFB45309), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}

/// Mention textuelle "PayPal" (pas de logo officiel embarqué dans l'application).
class PayPalWordmark extends StatelessWidget {
  final double size;
  final Color? color;
  const PayPalWordmark({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.account_balance_wallet_rounded, size: size + 2, color: color ?? SikaPayColors.paypalNavy),
        const SizedBox(width: 6),
        Text('PayPal',
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: color ?? SikaPayColors.paypalNavy)),
      ],
    );
  }
}

class StatusStyle {
  final Color color;
  final IconData icon;
  const StatusStyle(this.color, this.icon);
}

StatusStyle statusStyle(String status) {
  switch (status) {
    case 'COMPLETED':
      return const StatusStyle(AppColors.success, Icons.check_circle_rounded);
    case 'APPROVED':
      return const StatusStyle(SikaPayColors.paypalBlue, Icons.verified_rounded);
    case 'AWAITING_PAYPAL_APPROVAL':
    case 'CREATING_ORDER':
    case 'CAPTURING':
      return const StatusStyle(SikaPayColors.paypalBlue, Icons.hourglass_top_rounded);
    case 'AWAITING_USER_CONFIRMATION':
      return const StatusStyle(AppColors.brandPrimary, Icons.fact_check_rounded);
    case 'PENDING':
    case 'UNKNOWN_RESULT':
      return const StatusStyle(AppColors.warning, Icons.help_rounded);
    case 'CANCELLED':
    case 'EXPIRED':
      return const StatusStyle(Color(0xFF64748B), Icons.block_rounded);
    default:
      return const StatusStyle(AppColors.error, Icons.error_rounded);
  }
}

String statusShortLabel(String status, LanguageNotifier lang) {
  switch (status) {
    case 'AWAITING_USER_CONFIRMATION':
      return lang.tr('À confirmer', 'To confirm');
    case 'CREATING_ORDER':
      return lang.tr('Création…', 'Creating…');
    case 'AWAITING_PAYPAL_APPROVAL':
      return lang.tr('En attente PayPal', 'Awaiting PayPal');
    case 'APPROVED':
      return lang.tr('Approuvé', 'Approved');
    case 'CAPTURING':
      return lang.tr('Capture…', 'Capturing…');
    case 'COMPLETED':
      return lang.tr('Payé (capturé)', 'Paid (captured)');
    case 'PENDING':
      return lang.tr('En attente', 'Pending');
    case 'DECLINED':
      return lang.tr('Refusé', 'Declined');
    case 'CANCELLED':
      return lang.tr('Annulé', 'Cancelled');
    case 'EXPIRED':
      return lang.tr('Expiré', 'Expired');
    case 'UNKNOWN_RESULT':
      return lang.tr('À vérifier', 'To verify');
    default:
      return lang.tr('Échec', 'Failed');
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  final LanguageNotifier lang;
  const StatusChip({super.key, required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(st.icon, size: 13, color: st.color),
        const SizedBox(width: 4),
        Text(statusShortLabel(status, lang), style: TextStyle(color: st.color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

IconData categoryIcon(String? category) {
  switch (category) {
    case 'education':
      return Icons.school_rounded;
    case 'books':
      return Icons.menu_book_rounded;
    case 'design':
      return Icons.palette_rounded;
    default:
      return Icons.cloud_rounded;
  }
}

/// Étapes réelles du flux Orders v2 : préparé -> commande créée -> approuvée -> capturée.
int checkoutStepIndex(String status) {
  switch (status) {
    case 'AWAITING_USER_CONFIRMATION':
    case 'CREATING_ORDER':
      return 0;
    case 'AWAITING_PAYPAL_APPROVAL':
      return 1;
    case 'APPROVED':
    case 'CAPTURING':
    case 'UNKNOWN_RESULT':
    case 'PENDING':
      return 2;
    case 'COMPLETED':
      return 4;
    default:
      return -1;
  }
}

class CheckoutStepper extends StatelessWidget {
  final String status;
  final LanguageNotifier lang;
  const CheckoutStepper({super.key, required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    final idx = checkoutStepIndex(status);
    final steps = [
      lang.tr('Préparé par SIKA', 'Prepared by SIKA'),
      lang.tr('Commande PayPal créée', 'PayPal order created'),
      lang.tr('Approuvé sur PayPal', 'Approved on PayPal'),
      lang.tr('Paiement capturé', 'Payment captured'),
    ];
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    return Column(
      children: List.generate(steps.length, (i) {
        final done = idx > i || idx == 4;
        final current = idx == i;
        final color = done ? AppColors.success : (current ? SikaPayColors.paypalBlue : muted);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(done ? Icons.check_circle_rounded : (current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(steps[i],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: done || current ? Theme.of(context).colorScheme.onSurface : muted)),
            ),
          ]),
        );
      }),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Widget? trailing;
  const InfoRow({super.key, required this.label, required this.value, this.strong = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: onSurface.withValues(alpha: strong ? 0.9 : 0.6), fontSize: strong ? 15 : 13.5,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
        ),
        trailing ??
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: strong ? 17 : 13.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
            ),
      ]),
    );
  }
}

class SikaPayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SikaPayCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderStrong),
      ),
      child: child,
    );
  }
}
