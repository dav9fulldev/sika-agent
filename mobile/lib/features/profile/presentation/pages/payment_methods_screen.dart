import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/payment_provider.dart';
import '../widgets/add_payment_method_modal.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langNotifier = ref.watch(languageProvider.notifier);
    final user = ref.watch(authProvider).user;
    final isPremium = user?.isPremium ?? false;
    final paymentState = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          langNotifier.tr('Méthodes de paiement', 'Payment Methods'),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Status Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.amber, Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium
                              ? langNotifier.tr(
                                  'Sika Premium Actif', 'Sika Premium Active')
                              : langNotifier.tr('Passez à Sika Premium',
                                  'Upgrade to Sika Premium'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPremium
                              ? langNotifier.tr(
                                  'Vous profitez de toutes les fonctionnalités avancées.',
                                  'You are enjoying all advanced features.')
                              : langNotifier.tr(
                                  'Débloquez l\'IA illimitée et plus encore.',
                                  'Unlock unlimited AI and more.'),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.70),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              langNotifier.tr(
                  'Vos cartes et comptes', 'Your cards and accounts'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            if (paymentState.methods.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.border, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.credit_card_off_rounded,
                          color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        langNotifier.tr(
                            'Aucune méthode de paiement', 'No payment method'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langNotifier.tr(
                            'Ajoutez une carte ou un compte Mobile Money pour commencer.',
                            'Add a card or Mobile Money account to get started.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...paymentState.methods.map((method) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPaymentMethodTile(
                        context, method, ref, langNotifier),
                  )),

            const SizedBox(height: 24),

            // Add Payment Method Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  AddPaymentMethodModal.show(context);
                },
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.cyan),
                label: Text(
                  langNotifier.tr(
                      'Ajouter un moyen de paiement', 'Add payment method'),
                  style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(BuildContext context, PaymentMethod method,
      WidgetRef ref, LanguageNotifier langNotifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: method.isDefault
              ? AppColors.emerald.withValues(alpha: 0.5)
              : AppColors.border,
          width: method.isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              method.type == 'card'
                  ? Icons.credit_card_rounded
                  : Icons.phone_android_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (method.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Défaut',
                          style: TextStyle(
                            color: AppColors.emerald,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  method.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon:
                const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: Theme.of(context).scaffoldBackgroundColor,
            onSelected: (value) {
              if (value == 'default') {
                ref.read(paymentProvider.notifier).setDefault(method.id);
              } else if (value == 'delete') {
                ref
                    .read(paymentProvider.notifier)
                    .removePaymentMethod(method.id);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'default',
                child: Text(
                  langNotifier.tr('Définir par défaut', 'Set as default'),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  langNotifier.tr('Supprimer', 'Delete'),
                  style: const TextStyle(color: AppColors.rose),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
