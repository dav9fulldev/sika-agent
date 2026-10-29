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

/// Libellé lisible d'un événement du journal d'audit (null = détail technique non affiché).
String? eventLabel(Map<String, dynamic> e, LanguageNotifier lang) {
  final type = e['event_type']?.toString() ?? '';
  final reason = e['reason']?.toString() ?? '';
  if (type == 'CHECKOUT_PREPARED') return lang.tr('Préparé par SIKA', 'Prepared by SIKA');
  if (type == 'USER_CONFIRMED') return lang.tr('Confirmé par vous', 'Confirmed by you');
  if (type == 'AGENT_CONFIRMED') return lang.tr('Confirmé par SIKA avec votre autorisation', 'Confirmed by SIKA with your authorization');
  if (type == 'PAYPAL_ORDER_CREATED') return lang.tr('Commande PayPal créée', 'PayPal order created');
  if (type == 'PAID_WITH_SAVED_PAYPAL') return lang.tr('Payé avec votre compte PayPal relié', 'Paid with your linked PayPal account');
  if (type == 'PAYPAL_APPROVED_SAVED_PAYPAL') return null;
  if (type.startsWith('PAYPAL_APPROVED')) return lang.tr('Approuvé par vous sur PayPal', 'Approved by you on PayPal');
  if (type.startsWith('PAYPAL_CAPTURE_COMPLETED')) return lang.tr('Paiement capturé par PayPal', 'Payment captured by PayPal');
  if (type.startsWith('PAYPAL_CAPTURE_PENDING')) return lang.tr('Capture en attente chez PayPal', 'Capture pending at PayPal');
  if (type.startsWith('PAYPAL_CAPTURE_REFUNDED') || type.startsWith('PAYPAL_CAPTURE_PARTIALLY_REFUNDED')) {
    return lang.tr('Remboursé par le marchand', 'Refunded by the merchant');
  }
  if (type.startsWith('PAYPAL_CAPTURE_DECLINED') || type.startsWith('PAYPAL_CAPTURE_FAILED') || type.startsWith('CAPTURE_REFUSED')) {
    return lang.tr('Paiement refusé par PayPal', 'Payment refused by PayPal');
  }
  if (type.startsWith('CAPTURE_REJECTED')) return lang.tr('PayPal demande une nouvelle approbation', 'PayPal asks for a new approval');
  if (type == 'PAYPAL_WEBHOOK_RECEIVED') {
    return lang.tr('Notification PayPal reçue', 'PayPal notification received') + (reason.isNotEmpty ? ' · $reason' : '');
  }
  if (type == 'CHECKOUT_CANCELLED' || type == 'PAYER_CANCELLED_AT_PAYPAL' || type.startsWith('PAYPAL_VOIDED')) {
    return lang.tr('Annulé — aucun paiement', 'Cancelled — no payment');
  }
  if (type == 'CHECKOUT_EXPIRED' || type == 'PAYPAL_ORDER_NOT_FOUND') return lang.tr('Expiré — aucun paiement', 'Expired — no payment');
  if (type == 'CHECKOUT_INVALIDATED') return lang.tr('Remplacé par une demande plus récente', 'Replaced by a newer request');
  if (type.contains('NETWORK_ERROR') || type.contains('UNVERIFIED') || type.contains('MISMATCH')) {
    return lang.tr('Résultat à vérifier auprès de PayPal', 'Result to verify with PayPal');
  }
  if (type.contains('REJECTED') || type.contains('INVALID')) return lang.tr('Refusé par PayPal', 'Rejected by PayPal');
  return null; // étapes internes (début de capture, retour du navigateur…)
}

/// Message d'erreur dans la langue de l'utilisateur ; repli sur le message du serveur (anglais).
String paypalErrorText(String? code, String? serverMessage, LanguageNotifier lang) {
  final fr = <String, String>{
    'INSTRUMENT_DECLINED': 'Le moyen de paiement a été refusé. Choisissez-en un autre sur PayPal.',
    'REDIRECT_PAYER_FOR_ALTERNATE_FUNDING': 'PayPal vous demande de choisir un autre moyen de paiement.',
    'PAYER_ACTION_REQUIRED': 'PayPal attend encore une action de votre part. Ouvrez PayPal pour continuer.',
    'ORDER_NOT_APPROVED': "La commande n'est pas encore approuvée. Approuvez-la sur PayPal.",
    'PAYER_CANNOT_PAY': 'PayPal ne peut pas accepter de paiement depuis ce compte. Essayez un autre compte PayPal. Aucun débit.',
    'TRANSACTION_REFUSED': 'PayPal a refusé cette transaction. Vérifiez votre compte PayPal. Aucun débit.',
    'MAX_NUMBER_OF_PAYMENT_ATTEMPTS_EXCEEDED': 'Trop de tentatives. Utilisez un autre moyen de paiement. Aucun débit.',
    'PAYMENT_DENIED': 'PayPal a refusé ce paiement. Aucun débit.',
    'CANNOT_PAY_SELF': "L'acheteur et le marchand sont le même compte PayPal. Payez avec un autre compte. Aucun débit.",
    'CURRENCY_NOT_SUPPORTED': "PayPal n'accepte pas cette devise pour ce compte. Aucun paiement.",
    'ORDER_EXPIRED': "PayPal ne connaît plus cette commande (expirée). Aucun paiement n'a été fait.",
    'CHECKOUT_EXPIRED': 'Ce paiement a expiré avant confirmation. Demandez à SIKA de le préparer à nouveau.',
    'PAYPAL_UNREACHABLE': "PayPal est injoignable. Rien n'a été débité ; vous pouvez réessayer.",
    'NO_ACTIVE_AUTHORIZATION': "Vous n'avez pas autorisé SIKA à confirmer pour vous. Confirmez dans l'app.",
    'ABOVE_AUTHORIZED_AMOUNT': 'Montant au-dessus de votre autorisation. Confirmez-le vous-même.',
    'DAILY_LIMIT_REACHED': 'Limite quotidienne de votre autorisation atteinte. Confirmez-le vous-même.',
    'TIMEOUT': 'Pas de réponse à temps. Le dernier statut vérifié est affiché : revérifiez avant de réessayer.',
    'NETWORK': "Pas de connexion au serveur SIKA. Rien de nouveau n'a été envoyé à PayPal.",
    'UNEXPECTED': 'Une erreur est survenue. Le dernier statut vérifié est affiché : revérifiez avant de réessayer.',
  };
  if (!lang.isEnglish && code != null && fr.containsKey(code)) return fr[code]!;
  return serverMessage ?? lang.tr('Une erreur est survenue.', 'Something went wrong.');
}

bool isRefunded(Map<String, dynamic> paypal) {
  final s = paypal['capture_status']?.toString() ?? '';
  return s == 'REFUNDED' || s == 'PARTIALLY_REFUNDED';
}
