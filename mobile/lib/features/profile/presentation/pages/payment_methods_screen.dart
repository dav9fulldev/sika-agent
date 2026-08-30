import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/payment_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../../core/widgets/sika_empty_state.dart';
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          langNotifier.tr('Méthodes de paiement', 'Payment Methods'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Status Banner
            SikaGlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: AppColors.amber,
                        size: 32),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          isPremium
                              ? langNotifier.tr(
                                  'Vous profitez de toutes les fonctionnalités avancées.',
                                  'You are enjoying all advanced features.')
                              : langNotifier.tr(
                                  'Débloquez l\'IA illimitée et plus encore.',
                                  'Unlock unlimited AI and more.'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.70),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            Text(
              langNotifier.tr(
                  'Vos cartes et comptes', 'Your cards and accounts'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (paymentState.methods.isEmpty)
              SikaEmptyState(
                icon: Icons.credit_card_off_rounded,
                title: langNotifier.tr('Aucune méthode de paiement', 'No payment method'),
                message: langNotifier.tr(
                  'Ajoutez une carte ou un compte Mobile Money pour commencer.',
                  'Add a card or Mobile Money account to get started.',
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
              child: SikaPremiumButton(
                onPressed: () {
                  AddPaymentMethodModal.show(context);
                },
                text: langNotifier.tr('Ajouter un moyen de paiement', 'Add payment method'),
                prefixWidget: const Icon(Icons.add_circle_outline_rounded, color: AppColors.cyan),
                isSecondary: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(BuildContext context, PaymentMethod method,
      WidgetRef ref, LanguageNotifier langNotifier) {
    return SikaGlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
              borderRadius: AppSpacing.borderRadiusSm,
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Icon(
              method.type == 'card'
                  ? Icons.credit_card_rounded
                  : Icons.phone_android_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (method.isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Défaut',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.emerald,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon:
                const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
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
