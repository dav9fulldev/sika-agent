import 'package:flutter/material.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 1. VARIABLE D'ÉTAT DE LANGUE INITIALISÉE SUR 'English' PAR DÉFAUT
  String _currentLanguage = 'English';

  // États d'activation des permissions et services natifs
  bool _wakeWordEnabled = true;
  bool _overlayEnabled = true;
  bool _notificationsEnabled = true;
  bool _proactiveGuardianEnabled = true;
  bool _voiceAssistantEnabled = true;

  // États pour les switchs de préférences générales
  bool _notificationPrefEnabled = true;

  // 2 & 3. DÉCLENCHEMENT DU BOTTOM SHEET PREMIUM DE SÉLECTION DE LANGUE
  void _showLanguageBottomSheet() {
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
                  const Text(
                    'Choisir la langue / Language',
                    style: TextStyle(
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
              _buildLanguageOption('English', 'English'),
              const SizedBox(height: 8),
              _buildLanguageOption('Français', 'Français'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String langName, String value) {
    final bool isSelected = _currentLanguage == value;
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
          // 4. FERMETURE DU BOTTOMSHEET ET MISE À JOUR DYNAMIQUE PAR SETSTATE
          Navigator.pop(context);
          setState(() {
            _currentLanguage = value;
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 1. SECTION COMPTE ÉPURÉE
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Compte',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.lock_outline_rounded,
            title: 'Sécurité',
            subtitle: 'PIN, biométrie',
            onTap: () {},
          ),

          const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),

          // 2. SECTION PRÉFÉRENCES
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Préférences',
              style: TextStyle(
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
            title: const Text(
              'Notifications',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.cyan, size: 22),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          // 5. CORRECTION DU TEXTE TRAILING DYNAMIQUE UTILISANT _currentLanguage
          _buildActionTile(
            icon: Icons.language_rounded,
            title: 'Langue',
            trailingText: _currentLanguage,
            onTap: _showLanguageBottomSheet,
          ),
          _buildActionTile(
            icon: Icons.payments_outlined,
            title: 'Devise',
            trailingText: 'FCFA',
            onTap: () {},
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
            title: const Text(
              'Mot-clé "Sika" (Wake Word)',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Permet d\'appeler SIKA en arrière-plan sans ouvrir l\'application.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
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
            title: const Text(
              'Bulle Flottante Android (Overlay)',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Affiche des alertes proactives au-dessus des autres applications.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
            ),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            title: const Text(
              'Perception des Notifications Mobile Money',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Autorise SIKA à lire les alertes Wave, Orange Money et MTN.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
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
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              'Version SIKA Agent',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'v1.0.0 (All Things Agentic Taskmaster)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            trailing: Icon(Icons.info_outline, color: Color(0xFF475569), size: 20),
          ),
        ],
      ),
    );
  }

  // COMPOSANT REUTILISABLE POUR LES LIGNES INTERACTIVES DU COMPTE ET DES PREFERENCES
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
