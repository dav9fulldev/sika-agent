import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // États d'activation des permissions et services natifs
  bool _wakeWordEnabled = true;
  bool _overlayEnabled = true;
  bool _notificationsEnabled = true;
  bool _proactiveGuardianEnabled = true;
  bool _voiceAssistantEnabled = true;

  // États pour les switchs de préférences générales
  bool _notificationPrefEnabled = true;

  // DÉCLENCHEMENT DU BOTTOM SHEET DE SÉLECTION DE LANGUE
  void _showLanguageBottomSheet(LanguageNotifier langNotifier, String currentLang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDarker,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDarker,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langNotifier.tr('Choisir la langue', 'Choose Language'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildLanguageOption('English', 'English', currentLang, langNotifier),
              const SizedBox(height: 8),
              _buildLanguageOption('Français', 'Français', currentLang, langNotifier),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String langName, String value, String currentLang, LanguageNotifier langNotifier) {
    final bool isSelected = currentLang == value;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0B1329) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () {
          Navigator.pop(context);
          langNotifier.setLanguageByString(value);
        },
        title: Text(
          langName,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
            : null,
      ),
    );
  }

  // DÉCLENCHEMENT DU BOTTOM SHEET DE SÉLECTION DE DEVISE (AVEC TAUX DE CHANGE)
  void _showCurrencyBottomSheet(CurrencyNotifier currNotifier, AppCurrency currentCurr, LanguageNotifier langNotifier) {
    final currencies = [
      {'code': 'FCFA', 'name': 'Franc CFA (XOF)', 'currency': AppCurrency.fcfa},
      {'code': 'USD', 'name': 'US Dollar (\$)', 'currency': AppCurrency.usd},
      {'code': 'EUR', 'name': 'Euro (€)', 'currency': AppCurrency.eur},
      {'code': 'GBP', 'name': 'British Pound (£)', 'currency': AppCurrency.gbp},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDarker,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDarker,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langNotifier.tr('Choisir la devise', 'Choose Currency'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...currencies.map((item) {
                final curr = item['currency'] as AppCurrency;
                final bool isSelected = currentCurr == curr;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0B1329) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () {
                      Navigator.pop(context);
                      currNotifier.setCurrency(curr);
                    },
                    title: Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAppLanguage = ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);
    final String currentLang = currentAppLanguage.displayName;

    final currentAppCurrency = ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);
    final String currentCurrStr = currentAppCurrency.code;

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
          langNotifier.tr('Paramètres', 'Settings'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 1. SECTION COMPTE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              langNotifier.tr('Compte', 'Account'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.lock_outline_rounded,
            title: langNotifier.tr('Sécurité', 'Security'),
            subtitle: langNotifier.tr('PIN, biométrie', 'PIN, biometrics'),
            onTap: () {},
          ),

          const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),

          // 2. SECTION PRÉFÉRENCES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              langNotifier.tr('Préférences', 'Preferences'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            value: _notificationPrefEnabled,
            onChanged: (val) => setState(() => _notificationPrefEnabled = val),
            title: Text(
              langNotifier.tr('Notifications', 'Notifications'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.cyan, size: 22),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          _buildActionTile(
            icon: Icons.language_rounded,
            title: langNotifier.tr('Langue', 'Language'),
            trailingText: currentLang,
            onTap: () => _showLanguageBottomSheet(langNotifier, currentLang),
          ),
          _buildActionTile(
            icon: Icons.payments_outlined,
            title: langNotifier.tr('Devise', 'Currency'),
            trailingText: currentCurrStr,
            onTap: () => _showCurrencyBottomSheet(currNotifier, currentAppCurrency, langNotifier),
          ),

          const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),

          // 3. SECTION VOICE & WAKE WORD
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'VOICE & WAKE WORD',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          SwitchListTile(
            value: _wakeWordEnabled,
            onChanged: (val) {
              setState(() => _wakeWordEnabled = val);
              if (val) {
                SikaNativeService.startSikaService();
              } else {
                SikaNativeService.stopSikaService();
              }
            },
            title: Text(
              langNotifier.tr('Mot-clé "Sika" (Wake Word)', 'Wake Word "Sika"'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              langNotifier.tr(
                'Permet d\'appeler SIKA en arrière-plan sans ouvrir l\'application.',
                'Allows calling SIKA in background without opening the app.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
            ),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),

          const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),

          // 4. SECTION PERCEPTION & OVERLAY
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'PERCEPTION & OVERLAY',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          SwitchListTile(
            value: _overlayEnabled,
            onChanged: (val) => setState(() => _overlayEnabled = val),
            title: Text(
              langNotifier.tr('Bulle Flottante Android (Overlay)', 'Android Floating Bubble (Overlay)'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              langNotifier.tr(
                'Affiche des alertes proactives au-dessus des autres applications.',
                'Displays proactive alerts on top of other applications.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
            ),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            title: Text(
              langNotifier.tr(
                'Perception des Notifications Mobile Money',
                'Mobile Money Notification Perception',
              ),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              langNotifier.tr(
                'Autorise SIKA à lire les alertes Wave, Orange Money et MTN.',
                'Allows SIKA to read Wave, Orange Money and MTN alerts.',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
            ),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),

          const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),

          // 5. SECTION SIKA SERVICES
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Sika Services',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            value: _proactiveGuardianEnabled,
            onChanged: (val) => setState(() => _proactiveGuardianEnabled = val),
            title: const Text(
              'Proactive Guardian',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            secondary: const Icon(Icons.shield_outlined, color: AppColors.cyan, size: 22),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          SwitchListTile(
            value: _voiceAssistantEnabled,
            onChanged: (val) => setState(() => _voiceAssistantEnabled = val),
            title: const Text(
              'Voice Assistant',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            secondary: const Icon(Icons.keyboard_voice_outlined, color: AppColors.cyan, size: 22),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),

          const Divider(color: Color(0xFF1E293B), height: 32, thickness: 1),

          // 6. VERSION EN BAS DE PAGE
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              langNotifier.tr('Version SIKA Agent', 'SIKA Agent Version'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'v1.0.0 (All Things Agentic Taskmaster)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            trailing: const Icon(Icons.info_outline, color: Color(0xFF475569), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: AppColors.cyan, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFF334155),
            size: 14,
          ),
        ],
      ),
    );
  }
}
