import 'package:flutter/material.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _wakeWordEnabled = true;
  bool _overlayEnabled = true;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Agent Settings & Permissions',
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
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            subtitle: const Text(
              'Permet d\'appeler SIKA en arrière-plan sans ouvrir l\'application.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            activeThumbColor: const Color(0xFF10B981),
          ),
          const Divider(color: Color(0xFF334155)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'PERCEPTION & OVERLAY',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          SwitchListTile(
            value: _overlayEnabled,
            onChanged: (val) {
              setState(() => _overlayEnabled = val);
            },
            title: const Text(
              'Bulle Flottante Android (Overlay)',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Affiche des alertes proactives au-dessus des autres applications.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            activeThumbColor: const Color(0xFF10B981),
          ),
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
            },
            title: const Text(
              'Perception des Notifications Mobile Money',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Autorise SIKA à lire les alertes Wave, Orange Money et MTN.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            activeThumbColor: const Color(0xFF10B981),
          ),
          const Divider(color: Color(0xFF334155)),
          const ListTile(
            title: Text(
              'Version SIKA Agent',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              'v1.0.0 (All Things Agentic Taskmaster)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            trailing: Icon(Icons.info_outline, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
