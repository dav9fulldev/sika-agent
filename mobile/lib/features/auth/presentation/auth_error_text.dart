import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';

/// Message d'erreur dans la langue de l'app : codes connus traduits, sinon le message du serveur.
String authErrorText(AuthState auth, LanguageNotifier lang) {
  switch (auth.errorCode) {
    case 'USE_PAYPAL_SIGN_IN':
      return lang.tr('Ce compte utilise la connexion PayPal : touchez PayPal ci-dessous, ou créez un mot de passe avec « Mot de passe oublié ? ».',
          'This account uses PayPal sign-in: tap PayPal below, or set a password with "Forgot password?".');
    case 'USE_GOOGLE_SIGN_IN':
      return lang.tr('Ce compte utilise la connexion Google : touchez Google ci-dessous, ou créez un mot de passe avec « Mot de passe oublié ? ».',
          'This account uses Google sign-in: tap Google below, or set a password with "Forgot password?".');
    case 'PAYPAL_SIGN_IN_CANCELLED':
      return lang.tr('Connexion PayPal annulée.', 'PayPal sign-in cancelled.');
    case 'PAYPAL_SIGN_IN_TIMEOUT':
      return lang.tr("PayPal n'a pas répondu à temps. Réessayez.", 'PayPal did not respond in time. Try again.');
    case 'PAYPAL_OPEN_FAILED':
      return lang.tr("Impossible d'ouvrir PayPal.", 'Could not open PayPal.');
    case 'PAYPAL_SIGN_IN_FAILED':
      return lang.tr('Connexion PayPal impossible. Réessayez.', 'PayPal sign-in failed. Try again.');
    case 'GOOGLE_SIGN_IN_UNAVAILABLE':
    case 'GOOGLE_TOKEN_REQUIRED':
    case 'GOOGLE_TOKEN_INVALID':
      return lang.tr('Connexion Google indisponible pour le moment. Utilisez PayPal ou votre e-mail.',
          'Google sign-in is not available right now. Use PayPal or your email.');
    case 'NETWORK_UNAVAILABLE':
      return lang.tr('Pas de connexion internet ou serveur SIKA injoignable. Vérifiez votre connexion et réessayez.',
          'No internet connection or SIKA server unreachable. Check your connection and try again.');
    case 'FIELDS_REQUIRED':
      return lang.tr('Veuillez remplir tous les champs.', 'Please fill in all fields.');
    case 'EMAIL_REQUIRED':
      return lang.tr('Veuillez entrer votre adresse e-mail.', 'Please enter your email address.');
    case 'INVALID_CREDENTIALS':
      return lang.tr('Adresse e-mail ou mot de passe incorrect.', 'Invalid email or password.');
    default:
      return auth.errorMessage ?? '';
  }
}
