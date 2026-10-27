import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Vrai seulement si une empreinte ou un visage est réellement enregistré :
  /// un capteur sans donnée enregistrée fait échouer chaque authentification.
  Future<bool> isBiometricsAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Veuillez vous authentifier pour valider ce paiement SIKA Pay.',
  }) async {
    try {
      final bool isAvailable = await isBiometricsAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
