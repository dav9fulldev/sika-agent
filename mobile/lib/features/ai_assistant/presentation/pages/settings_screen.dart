import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _currentAlias = 'SIKA';

  @override
  void initState() {
    super.initState();
    _loadCurrentAlias();
  }

  Future<void> _loadCurrentAlias() async {
    final alias = await SikaNativeService.getSikaAlias();
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('wake_word_enabled') ?? true;
    if (alias != null && alias.isNotEmpty) {
      setState(() {
        _currentAlias = alias.toUpperCase();
        _wakeWordEnabled = isEnabled;
      });
    } else {
      setState(() {
        _wakeWordEnabled = isEnabled;
      });
    }
  }

  void _showAliasBottomSheet(LanguageNotifier langNotifier) {
    final TextEditingController aliasController = TextEditingController(text: _currentAlias);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langNotifier.tr('Nom de l\'assistant', 'Assistant Name'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            size: 24),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: aliasController,
                    maxLength: 15,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: langNotifier.tr('Nom personnalisé', 'Custom Name'),
                      hintText: 'Ex: KIMI',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF10B981)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null; // Will default to SIKA
                      }
                      if (value.trim().length > 15) {
                        return 'Maximum 15 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    langNotifier.tr(
                      'Information : SIKA reste toujours disponible comme nom de secours.',
                      'Info: SIKA is always available as a fallback name.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          String newAlias = aliasController.text.trim().toUpperCase();
                          if (newAlias.isEmpty) {
                            newAlias = 'SIKA';
                          }
                          Navigator.pop(context);
                          setState(() => _currentAlias = newAlias);
                          await SikaNativeService.setSikaAlias(newAlias.toLowerCase());
                          // Redémarrer le service si actif pour prendre en compte le nouveau nom
                          if (_wakeWordEnabled) {
                            await SikaNativeService.stopSikaService();
                            await Future.delayed(const Duration(milliseconds: 500));
                            await SikaNativeService.startSikaService();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        langNotifier.tr('Enregistrer', 'Save'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLanguageBottomSheet(
      LanguageNotifier langNotifier, String currentLang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLanguageOption(
                  'English', 'English', currentLang, langNotifier),
              const SizedBox(height: 8),
              _buildLanguageOption(
                  'Français', 'Français', currentLang, langNotifier),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String langName, String value, String currentLang,
      LanguageNotifier langNotifier) {
    final bool isSelected = currentLang == value;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.transparent,
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
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
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
  void _showCurrencyBottomSheet(CurrencyNotifier currNotifier,
      AppCurrency currentCurr, LanguageNotifier langNotifier) {
    final currencies = [
      {'code': 'FCFA', 'name': 'Franc CFA (XOF)', 'currency': AppCurrency.fcfa},
      {'code': 'USD', 'name': 'US Dollar (\$)', 'currency': AppCurrency.usd},
      {'code': 'EUR', 'name': 'Euro (€)', 'currency': AppCurrency.eur},
      {'code': 'GBP', 'name': 'British Pound (£)', 'currency': AppCurrency.gbp},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...currencies.map((item) {
                final curr = item['currency'] as AppCurrency;
                final bool isSelected = currentCurr == curr;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onTap: () {
                      Navigator.pop(context);
                      currNotifier.setCurrency(curr);
                    },
                    title: Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF10B981), size: 22)
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
          langNotifier.tr('Paramètres', 'Settings'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
              langNotifier.tr('Compte', 'Account').toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SikaGlassCard(
              padding: EdgeInsets.zero,
              child: _buildActionTile(
                icon: Icons.lock_outline_rounded,
                title: langNotifier.tr('Sécurité', 'Security'),
                subtitle: langNotifier.tr('PIN, biométrie', 'PIN, biometrics'),
                onTap: () {},
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. SECTION PRÉFÉRENCES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              langNotifier.tr('Préférences', 'Preferences').toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SikaGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _notificationPrefEnabled,
                    onChanged: (val) => setState(() => _notificationPrefEnabled = val),
                    title: Text(
                      langNotifier.tr('Notifications', 'Notifications'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      langNotifier.tr('Mises à jour et alertes', 'Updates and alerts'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  Consumer(builder: (context, ref, child) {
                    final themeMode = ref.watch(themeProvider);
                    final isDark = themeMode == ThemeMode.dark;
                    return SwitchListTile(
                      value: isDark,
                      onChanged: (val) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                      title: Text(
                        langNotifier.tr('Mode Sombre', 'Dark Mode'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        langNotifier.tr('Activer le thème foncé', 'Enable dark theme'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      activeThumbColor: AppColors.brandPrimary,
                      activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    );
                  }),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  _buildActionTile(
                    icon: Icons.language_rounded,
                    title: langNotifier.tr('Langue', 'Language'),
                    trailingText: currentLang,
                    onTap: () => _showLanguageBottomSheet(langNotifier, currentLang),
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  _buildActionTile(
                    icon: Icons.payments_outlined,
                    title: langNotifier.tr('Devise', 'Currency'),
                    trailingText: currentCurrStr,
                    onTap: () => _showCurrencyBottomSheet(
                        currNotifier, currentAppCurrency, langNotifier),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 3. SECTION VOICE & WAKE WORD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'VOICE & WAKE WORD',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SikaGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _wakeWordEnabled,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('wake_word_enabled', val);
                      setState(() => _wakeWordEnabled = val);
                      if (val) {
                        SikaNativeService.startSikaService();
                      } else {
                        SikaNativeService.stopSikaService();
                      }
                    },
                    title: Text(
                      langNotifier.tr('Mot-clé "Sika" (Wake Word)', 'Wake Word "Sika"'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      langNotifier.tr(
                        'Permet d\'appeler SIKA en arrière-plan sans ouvrir l\'application.',
                        'Allows calling SIKA in background without opening the app.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  if (_wakeWordEnabled) ...[
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                    _buildActionTile(
                      icon: Icons.record_voice_over_rounded,
                      title: langNotifier.tr('Nom de l\'assistant', 'Assistant Name'),
                      trailingText: _currentAlias,
                      onTap: () => _showAliasBottomSheet(langNotifier),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 4. SECTION PERCEPTION & OVERLAY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'PERCEPTION & OVERLAY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SikaGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _overlayEnabled,
                    onChanged: (val) => setState(() => _overlayEnabled = val),
                    title: Text(
                      langNotifier.tr('Bulle Flottante Android (Overlay)',
                          'Android Floating Bubble (Overlay)'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      langNotifier.tr(
                        'Affiche des alertes proactives au-dessus des autres applications.',
                        'Displays proactive alerts on top of other applications.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: (val) => setState(() => _notificationsEnabled = val),
                    title: Text(
                      langNotifier.tr(
                        'Perception des Notifications Mobile Money',
                        'Mobile Money Notification Perception',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      langNotifier.tr(
                        'Autorise SIKA à lire les alertes Wave, Orange Money et MTN.',
                        'Allows SIKA to read Wave, Orange Money and MTN alerts.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 5. SECTION SIKA SERVICES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'SIKA SERVICES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SikaGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _proactiveGuardianEnabled,
                    onChanged: (val) => setState(() => _proactiveGuardianEnabled = val),
                    title: Text(
                      'Proactive Guardian',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.brandPrimary, size: 22),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  SwitchListTile(
                    value: _voiceAssistantEnabled,
                    onChanged: (val) => setState(() => _voiceAssistantEnabled = val),
                    title: Text(
                      'Voice Assistant',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_voice_outlined,
                          color: AppColors.brandPrimary, size: 22),
                    ),
                    activeThumbColor: AppColors.brandPrimary,
                    activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 6. VERSION EN BAS DE PAGE
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              langNotifier.tr('Version SIKA Agent', 'SIKA Agent Version'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'v1.0.0 (All Things Agentic Taskmaster)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            trailing: Icon(Icons.info_outline,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                size: 22),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.brandPrimary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
