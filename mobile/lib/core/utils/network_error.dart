import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

const _networkHints = [
  'SocketException',
  'Failed host lookup',
  'No address associated',
  'Connection refused',
  'Connection reset',
  'Connection closed',
  'Network is unreachable',
  'HandshakeException',
];

/// Vrai quand l'appel n'a pas atteint le serveur SIKA (pas de connexion, DNS, délai dépassé).
/// Ces erreurs ne doivent jamais être affichées telles quelles : l'écran montre un message traduit.
bool isNetworkError(Object e) {
  if (e is SocketException || e is HandshakeException || e is TimeoutException || e is http.ClientException) {
    return true;
  }
  final text = e.toString();
  return _networkHints.any(text.contains);
}
