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
  int _currentStep = 1; // 1 = Phone Number, 2 = 6-Digit OTP
  String _selectedProvider = 'Wave';
  String _authMethod = 'OAUTH2_WAVE';
  String? _sessionId;

  final TextEditingController _phoneController =
      TextEditingController(text: '+225 07 00 00 05');
  final TextEditingController _otpController =
      TextEditingController(text: '123456');

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
    {
      'name': 'PayMeChap',
      'image': AppImages.paymechap,
      'authMethod': 'PAYMECHAP_PARTNER_API',
      'brandColor': AppColors.cyan,
    },
  ];

  Future<void> _handleInitiateOtp() async {
    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();

    final sessId = await ref.read(walletProvider.notifier).initiateWalletConnection(
          provider: _selectedProvider,
          accountNumber: phone,
          authMethod: _authMethod,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (sessId != null) {
        setState(() {
          _sessionId = sessId;
          _currentStep = 2;
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _isSubmitting = true);
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.trim();

    final success = await ref.read(walletProvider.notifier).verifyWalletOtp(
          sessionId: _sessionId ?? 'otp_sess_demo',
          otpCode: otp,
          provider: _selectedProvider,
          accountNumber: phone,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('✅ Code OTP validé ! Compte $_selectedProvider raccordé à SIKA.'),
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

          if (_currentStep == 1) ...[
            // ÉTAPE 1 : CHOIX OPÉRATEUR & TÉLÉPHONE
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
                'Choisissez votre partenaire de paiement et entrez votre numéro de mobile.',
                'Choose your payment partner and enter your mobile number.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),

            const SizedBox(height: 20),

            // SELECTION FOURNISSEUR (WAVE, ORANGE, MTN, PAYMECHAP)
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
              langNotifier.tr('Numéro de téléphone du compte', 'Account Mobile Number'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
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

            // BADGE DE SÉCURITÉ OTP
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppColors.cyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedProvider == 'PayMeChap'
                          ? langNotifier.tr(
                              'Un code de sécurité OTP à 6 chiffres vous sera envoyé par Email (Revo) pour valider votre compte.',
                              'A 6-digit OTP security code will be sent via Email (Revo) to verify your account.',
                            )
                          : langNotifier.tr(
                              'Un code de sécurité OTP à 6 chiffres vous sera envoyé par SMS pour valider votre identité.',
                              'A 6-digit OTP security code will be sent via SMS to verify your identity.',
                            ),
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // BOUTON ENVOYER OTP
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleInitiateOtp,
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
                          'Recevoir le code OTP',
                          'Receive OTP Code',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ] else ...[
            // ÉTAPE 2 : SAISIE DU CODE OTP À 6 CHIFFRES
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _currentStep = 1),
                ),
                const SizedBox(width: 8),
                Text(
                  langNotifier.tr('Vérification du code OTP', 'OTP Code Verification'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              langNotifier.tr(
                'Entrez le code à 6 chiffres envoyé au ${_phoneController.text}.',
                'Enter the 6-digit code sent to ${_phoneController.text}.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),

            const SizedBox(height: 24),

            // CHAMP CODE OTP
            Text(
              langNotifier.tr('Code OTP à 6 chiffres', '6-Digit OTP Code'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: '123456',
                counterText: '',
                hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cyan),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cyan),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      langNotifier.tr(
                        'Code démo suggéré : 123456 (Validation instantanée par l\'opérateur).',
                        'Suggested demo code: 123456 (Instant operator verification).',
                      ),
                      style: const TextStyle(color: AppColors.emerald, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // BOUTON VALIDER OTP
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleVerifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        langNotifier.tr(
                          'Valider & Activer le compte',
                          'Validate & Activate Account',
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
        ],
      ),
    );
  }
}
