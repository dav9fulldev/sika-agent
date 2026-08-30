import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_surface.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';
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
  String _selectedProvider = '';
  String _authMethod = '';
  String? _sessionId;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

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

  String? _localErrorMessage;

  Future<void> _handleInitiateOtp() async {
    setState(() {
      _isSubmitting = true;
      _localErrorMessage = null;
    });
    final phone = _phoneController.text.trim();

    final sessId =
        await ref.read(walletProvider.notifier).initiateWalletConnection(
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
      } else {
        setState(() {
          _localErrorMessage = ref
                  .read(walletProvider)
                  .errorMessage
                  ?.replaceAll('Exception: ', '') ??
              'Numéro introuvable ou erreur de connexion.';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() {
      _isSubmitting = true;
      _localErrorMessage = null;
    });
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.trim();

    final success = await ref.read(walletProvider.notifier).verifyWalletOtp(
          sessionId: _sessionId!,
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
            content: Text(
                '✅ Code OTP validé ! Compte $_selectedProvider raccordé à SIKA.'),
          ),
        );
      } else {
        setState(() {
          _localErrorMessage = ref
                  .read(walletProvider)
                  .errorMessage
                  ?.replaceAll('Exception: ', '') ??
              'Code OTP incorrect ou expiré.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.24),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              langNotifier.tr(
                'Choisissez votre partenaire de paiement et entrez votre numéro de mobile.',
                'Choose your payment partner and enter your mobile number.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),

            if (_localErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              SikaSurface(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.rose, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _localErrorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

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
                    child: Container(
                      width: 105,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (prov['brandColor'] as Color).withValues(alpha: 0.1)
                            : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (prov['brandColor'] as Color)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [] : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
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
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : AppColors.textMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // CHAMP NUMERO DE COMPTE
            Text(
              langNotifier.tr(
                  'Numéro de téléphone du compte', 'Account Mobile Number'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SikaGlassTextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              hintText: '+225 07 00 00 00',
              prefixIcon: Icons.phone,
            ),

            const SizedBox(height: AppSpacing.md),

            // BADGE DE SÉCURITÉ OTP
            SikaSurface(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, color: AppColors.cyan, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: SikaPremiumButton(
                onPressed: _isSubmitting ? () {} : _handleInitiateOtp,
                text: langNotifier.tr('Recevoir le code', 'Get Code'),
                isLoading: _isSubmitting,
              ),
            ),
          ] else if (_currentStep == 2) ...[
            // ÉTAPE 2 : SAISIE DU CODE OTP À 6 CHIFFRES
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => setState(() => _currentStep = 1),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  langNotifier.tr(
                      'Vérification du code OTP', 'OTP Code Verification'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              langNotifier.tr(
                'Entrez le code à 6 chiffres envoyé au ${_phoneController.text}.',
                'Enter the 6-digit code sent to ${_phoneController.text}.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),

            if (_localErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              SikaSurface(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.rose, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _localErrorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // CHAMP CODE OTP
            Text(
              langNotifier.tr('Code OTP à 6 chiffres', '6-Digit OTP Code'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                decoration: InputDecoration(
                  hintText: 'Entrez le code reçu par SMS',
                  counterText: '',
                  hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 8,
                      ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 8),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: SikaPremiumButton(
                onPressed: _isSubmitting ? () {} : _handleVerifyOtp,
                text: langNotifier.tr('Valider & Activer le compte', 'Validate & Activate Account'),
                isLoading: _isSubmitting,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // BOUTON RENVOYER OTP
            Center(
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        _otpController.clear();
                        await _handleInitiateOtp();
                        if (context.mounted && _localErrorMessage == null) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               backgroundColor: AppColors.cyan,
                               content: Text(langNotifier.tr(
                                   'Un nouveau code a été envoyé.',
                                   'A new code has been sent.')),
                             ),
                           );
                        }
                      },
                child: Text(
                  langNotifier.tr('Renvoyer le code OTP', 'Resend OTP Code'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
