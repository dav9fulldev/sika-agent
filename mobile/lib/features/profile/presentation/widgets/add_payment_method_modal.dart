import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/payment_provider.dart';

class AddPaymentMethodModal extends ConsumerStatefulWidget {
  const AddPaymentMethodModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const AddPaymentMethodModal(),
      ),
    );
  }

  @override
  ConsumerState<AddPaymentMethodModal> createState() => _AddPaymentMethodModalState();
}

class _AddPaymentMethodModalState extends ConsumerState<AddPaymentMethodModal> {
  int _selectedType = 0; // 0 for Card, 1 for Mobile Money
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    PaymentMethod newMethod;
    
    if (_selectedType == 0) {
      final last4 = _cardNumberController.text.length >= 4 
          ? _cardNumberController.text.substring(_cardNumberController.text.length - 4) 
          : 'XXXX';
      newMethod = PaymentMethod(
        id: id,
        type: 'card',
        title: 'Visa terminant par $last4',
        subtitle: 'Expire ${_expiryController.text.isEmpty ? '12/28' : _expiryController.text}',
      );
    } else {
      newMethod = PaymentMethod(
        id: id,
        type: 'mobile_money',
        title: 'Mobile Money',
        subtitle: _phoneController.text.isEmpty ? '+225 0102030405' : _phoneController.text,
      );
    }

    ref.read(paymentProvider.notifier).addPaymentMethod(newMethod);
    setState(() => _isSaving = false);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langNotifier = ref.watch(languageProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                langNotifier.tr('Ajouter un moyen', 'Add a method'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTypeSelector(
                  index: 0,
                  icon: Icons.credit_card_rounded,
                  title: 'Carte bancaire',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeSelector(
                  index: 1,
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile Money',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_selectedType == 0) ...[
            _buildTextField(
              label: 'Numéro de carte',
              controller: _cardNumberController,
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Expiration (MM/AA)',
                    controller: _expiryController,
                    icon: Icons.date_range_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'CVC',
                    controller: TextEditingController(),
                    icon: Icons.security_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Nom du titulaire',
              controller: TextEditingController(),
              icon: Icons.person_outline_rounded,
            ),
          ] else ...[
            _buildTextField(
              label: 'Numéro Mobile Money',
              controller: _phoneController,
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
          ],
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                  : Text(
                      langNotifier.tr('Ajouter', 'Add'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector({required int index, required IconData icon, required String title}) {
    final isSelected = _selectedType == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? Theme.of(context).colorScheme.onSurface : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
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
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1)),
      ),
    );
  }
}
