import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences d'entrée de l'appareil :
/// - la biométrie est proposée une fois (activer maintenant / plus tard) ;
/// - si elle est activée, une session restaurée doit être déverrouillée (par session).
/// La complétude du profil, elle, vient du serveur (champs manquants, statut KYC).
class AppSetupState {
  final bool loaded;
  final bool biometricDecided;
  final bool biometricEnabled;
  final bool unlocked;

  const AppSetupState({
    this.loaded = false,
    this.biometricDecided = false,
    this.biometricEnabled = false,
    this.unlocked = false,
  });

  AppSetupState copyWith({bool? loaded, bool? biometricDecided, bool? biometricEnabled, bool? unlocked}) {
    return AppSetupState(
      loaded: loaded ?? this.loaded,
      biometricDecided: biometricDecided ?? this.biometricDecided,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}

class AppSetupNotifier extends StateNotifier<AppSetupState> {
  static const _decidedKey = 'sika_biometric_decided';
  static const _enabledKey = 'sika_biometric_enabled';

  AppSetupNotifier() : super(const AppSetupState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Fusion : un choix fait pendant le chargement ne doit pas être écrasé
      state = state.copyWith(
        loaded: true,
        biometricDecided: state.biometricDecided || (prefs.getBool(_decidedKey) ?? false),
        biometricEnabled: state.biometricEnabled || (prefs.getBool(_enabledKey) ?? false),
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  void unlock() => state = state.copyWith(unlocked: true);

  /// Appelé à la déconnexion : la prochaine session devra être déverrouillée à nouveau.
  void lock() => state = state.copyWith(unlocked: false);

  /// Choix de l'utilisateur sur l'écran de sécurisation (ou passage automatique sans capteur).
  Future<void> setBiometric({required bool enabled}) async {
    state = state.copyWith(biometricDecided: true, biometricEnabled: enabled, unlocked: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_decidedKey, true);
    await prefs.setBool(_enabledKey, enabled);
  }
}

final appSetupProvider = StateNotifierProvider<AppSetupNotifier, AppSetupState>((ref) => AppSetupNotifier());
