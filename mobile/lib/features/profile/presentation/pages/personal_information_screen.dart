import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends ConsumerState<PersonalInformationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController =
        TextEditingController(text: user?.phone ?? '+225 0102030405');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    setState(() => _isSaving = true);
    final langNotifier = ref.read(languageProvider.notifier);

    try {
      await ref.read(authProvider.notifier).updateUserInfo(
            _nameController.text,
            _phoneController.text,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langNotifier.tr(
                'Informations mises à jour !', 'Information updated!')),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langNotifier.tr(
                'Erreur lors de la mise à jour', 'Error during update')),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langNotifier = ref.watch(languageProvider.notifier);
    final user = ref.watch(authProvider).user;
    final userName = user?.name ?? 'Utilisateur';
    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

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
          langNotifier.tr('Informations personnelles', 'Personal Information'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.2), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPrimary.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                      child: Text(
                        initialLetter,
                        style: AppTypography.h1.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Form Fields
            SikaGlassCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  _buildTextField(
                    label: langNotifier.tr('Nom complet', 'Full Name'),
                    controller: _nameController,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildTextField(
                    label: langNotifier.tr('Adresse Email', 'Email Address'),
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    readOnly: true, // Email is non-editable easily
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildTextField(
                    label: langNotifier.tr('Numéro de téléphone', 'Phone Number'),
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Save Button
            SikaPremiumButton(
              onPressed: _handleSave,
              isLoading: _isSaving,
              text: langNotifier.tr('Enregistrer', 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!readOnly)
          SikaGlassTextField(
            controller: controller,
            hintText: label,
            prefixIcon: icon,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              ),
            ),
            child: TextField(
              controller: controller,
              readOnly: true,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              decoration: InputDecoration(
                prefixIcon: Icon(icon,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                    size: 22),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              ),
            ),
          ),
      ],
    );
  }
}
