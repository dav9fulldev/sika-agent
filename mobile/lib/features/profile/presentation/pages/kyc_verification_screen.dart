import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  ConsumerState<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  void _nextStep() async {
    if (_currentStep == 1) {
      setState(() => _isProcessing = true);
      // Simulate API verification
      await Future.delayed(const Duration(seconds: 2));
      
      ref.read(authProvider.notifier).updateKycStatus(true);
      
      setState(() => _isProcessing = false);
      
      if (mounted) {
        final langNotifier = ref.read(languageProvider.notifier);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langNotifier.tr('Identité vérifiée avec succès !', 'Identity verified successfully!')),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _currentStep++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langNotifier = ref.watch(languageProvider.notifier);
    
    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          langNotifier.tr('Vérification d\'Identité', 'Identity Verification'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 0 ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 1 ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              if (_currentStep == 0) _buildIdCardStep(langNotifier)
              else _buildSelfieStep(langNotifier),
              
              const Spacer(),
              
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _currentStep == 0 
                              ? langNotifier.tr('Prendre une photo', 'Take a photo')
                              : langNotifier.tr('Soumettre pour vérification', 'Submit for verification'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdCardStep(LanguageNotifier langNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.badge_outlined, size: 80, color: AppColors.cyan),
        const SizedBox(height: 24),
        Text(
          langNotifier.tr('Pièce d\'identité', 'Identity Document'),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          langNotifier.tr(
            'Veuillez prendre une photo claire de votre pièce d\'identité (CNI, Passeport).',
            'Please take a clear photo of your identity document (ID Card, Passport).'
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 12),
              Text(
                langNotifier.tr('Appuyez pour scanner', 'Tap to scan'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelfieStep(LanguageNotifier langNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.face_retouching_natural_rounded, size: 80, color: AppColors.cyan),
        const SizedBox(height: 24),
        Text(
          langNotifier.tr('Selfie de sécurité', 'Security Selfie'),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          langNotifier.tr(
            'Prenez un selfie dans un endroit bien éclairé pour confirmer votre identité.',
            'Take a selfie in a well-lit area to confirm your identity.'
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 40),
        Container(
          width: 200,
          height: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_front_outlined, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 12),
              Text(
                langNotifier.tr('Ouvrir la caméra', 'Open camera'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
