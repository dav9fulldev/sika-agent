import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/wallet_provider.dart';

class ConnectWalletModal extends ConsumerStatefulWidget {
  const ConnectWalletModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ConnectWalletModal(),
    );
  }

  @override
  ConsumerState<ConnectWalletModal> createState() => _ConnectWalletModalState();
}

class _ConnectWalletModalState extends ConsumerState<ConnectWalletModal> {
  String _selectedProvider = 'Wave';
  String _authMethod = 'OAUTH2_WAVE';
  final TextEditingController _phoneController =
      TextEditingController(text: '+225 07 00 00 05');
  final TextEditingController _balanceController =
      TextEditingController(text: '15000');
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _providers = [
    {
      'name': 'Wave',
      'image': AppImages.waveci,
      'authMethod': 'OAUTH2_WAVE',
      'brandColor': Colors.blue,
    },
    {
      'name': 'Orange Money',
      'image': AppImages.orange,
      'authMethod': 'ORANGE_DEVELOPER_API',
      'brandColor': Colors.orange,
    },
    {
      'name': 'MTN MoMo',
      'image': AppImages.mtn,
      'authMethod': 'MTN_MOMO_API',
      'brandColor': Colors.amber,
    },
  ];

  Future<void> _handleConnect() async {
    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim()) ?? 10000.0;

    final success = await ref.read(walletProvider.notifier).connectNewWallet(
          provider: _selectedProvider,
          accountNumber: phone,
          authMethod: _authMethod,
          initialBalance: balance,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('✅ Compte $_selectedProvider connecté avec succès !'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDarker,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TITRE ÉPURÉ SANS JARGON TECHNIQUE
          Text(
            langNotifier.tr(
              'Connecter un portefeuille',
              'Connect a Wallet',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            langNotifier.tr(
              'Sélectionnez votre opérateur et entrez votre numéro de compte.',
              'Select your provider and enter your account number.',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),

          const SizedBox(height: 20),

          // SELECTION FOURNISSEUR (WAVE, ORANGE, MTN)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _providers.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) {
                final prov = _providers[index];
                final bool isSelected = _selectedProvider == prov['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProvider = prov['name'] as String;
                      _authMethod = prov['authMethod'] as String;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 105,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (prov['brandColor'] as Color).withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? (prov['brandColor'] as Color) : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            prov['image'] as String,
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Icon(
                              Icons.account_balance_wallet,
                              color: prov['brandColor'] as Color,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          prov['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // CHAMP NUMERO DE COMPTE
          Text(
            langNotifier.tr('Numéro de compte / Téléphone', 'Account Number / Phone'),
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              hintText: '+225 07 00 00 00',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.phone, color: AppColors.cyan),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CHAMP SOLDE DE DEPART
          Text(
            langNotifier.tr('Solde initial (FCFA)', 'Initial Balance (FCFA)'),
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              hintText: '15000',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.account_balance_wallet, color: AppColors.emerald),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // BOUTON VALIDER CONNEXION
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      langNotifier.tr(
                        'Connecter le portefeuille',
                        'Connect Wallet',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
