import '../../../paypal/presentation/pages/subscription_screen.dart';
import '../../../paypal/presentation/widgets/web_offers_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';
import 'agent_progress_widget.dart';
import '../../../paypal/presentation/widgets/paypal_checkout_card.dart';

class SikaChatBubble extends ConsumerWidget {
  final SikaMessage message;

  const SikaChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildSikaEditorial(context, ref);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildSikaEditorial(BuildContext context, WidgetRef ref) {
    final paragraphs = message.text.split('\n\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 32, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SIKA Small Icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Real observable agent execution steps (if any were performed)
                if (message.agentSteps != null && message.agentSteps!.isNotEmpty)
                  AgentProgressWidget(steps: message.agentSteps!),
                ...paragraphs.map((paragraph) {
                  final isLast = paragraph == paragraphs.last &&
                      message.suggestedTransaction == null;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Text(
                      paragraph,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                            height: 1.6,
                            fontSize: 15,
                          ),
                    ),
                  );
                }),
                if (message.suggestedTransaction != null)
                  _buildRichResponse(context, ref, message.suggestedTransaction!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichResponse(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    // SIKA Pay : checkout PayPal préparé par l'agent (statuts réels suivis par le backend)
    if (data['type'] == 'paypal_checkout' && data['checkout'] is Map) {
      return PayPalCheckoutCard(initialCheckout: Map<String, dynamic>.from(data['checkout'] as Map));
    }
    // Abonnement PayPal préparé par l'agent (confirmation par l'utilisateur)
    if (data['type'] == 'paypal_subscription' && data['subscription'] is Map) {
      return SubscriptionCard(subscription: Map<String, dynamic>.from(data['subscription'] as Map));
    }
    if (data['type'] == 'subscriptions_list' && data['subscriptions'] is List) {
      return Column(
          children: (data['subscriptions'] as List)
              .map((s) => SubscriptionCard(subscription: Map<String, dynamic>.from(s as Map)))
              .toList());
    }
    // Recherche web : offres de vrais marchands (comparaison, paiement sur leur site)
    if (data['type'] == 'web_offers' && data['products'] is List) {
      return WebOffersCard(data: data);
    }

    // Fallback card simple if not a known rich response
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
      ),
      child: Consumer(builder: (context, ref, _) => Text(
        ref.watch(languageProvider) == AppLanguage.french ? 'Opération disponible' : 'Action available',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
      )),
    );
  }
}
