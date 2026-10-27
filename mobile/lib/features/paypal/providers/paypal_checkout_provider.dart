import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/api_service_provider.dart';
import '../../../core/services/api_service.dart';
import '../../ai_assistant/providers/sika_provider.dart';

/// Vue locale d'un checkout SIKA Pay.
///
/// [data] est TOUJOURS la dernière réponse du backend : l'application n'invente
/// aucun statut, aucun montant et aucun résultat PayPal.
class PayPalCheckoutView {
  final Map<String, dynamic> data;
  final String? busy; // 'confirm' | 'capture' | 'cancel' | 'refresh'
  final String? errorCode;
  final String? errorMessage;

  const PayPalCheckoutView({required this.data, this.busy, this.errorCode, this.errorMessage});

  String get id => data['checkout_id']?.toString() ?? '';
  String get status => data['status']?.toString() ?? '';
  String get statusLabel => data['status_label']?.toString() ?? status;
  String? get nextAction => data['next_action']?.toString();
  bool get isTerminal => data['is_terminal'] == true;
  String get currency => data['currency']?.toString() ?? '';
  String get total => data['total_amount']?.toString() ?? '';
  String get unitAmount => data['unit_amount']?.toString() ?? '';
  int get quantity => (data['quantity'] as num?)?.toInt() ?? 1;
  String get detailsHash => data['details_hash']?.toString() ?? '';
  Map<String, dynamic> get item => Map<String, dynamic>.from(data['item'] as Map? ?? const {});
  Map<String, dynamic> get merchant => Map<String, dynamic>.from(data['merchant'] as Map? ?? const {});
  Map<String, dynamic> get budget => Map<String, dynamic>.from(data['budget'] as Map? ?? const {});
  Map<String, dynamic> get paypal => Map<String, dynamic>.from(data['paypal'] as Map? ?? const {});
  Map<String, dynamic> get provenance => Map<String, dynamic>.from(data['provenance'] as Map? ?? const {});
  Map<String, dynamic>? get lastError =>
      data['last_error'] is Map ? Map<String, dynamic>.from(data['last_error'] as Map) : null;
  List<Map<String, dynamic>> get events => (data['events'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  PayPalCheckoutView copyWith({
    Map<String, dynamic>? data,
    String? busy,
    bool clearBusy = false,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PayPalCheckoutView(
      data: data ?? this.data,
      busy: clearBusy ? null : (busy ?? this.busy),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PayPalCheckoutsNotifier extends StateNotifier<Map<String, PayPalCheckoutView>> {
  final ApiService _api;
  final Ref _ref;

  PayPalCheckoutsNotifier(this._api, this._ref) : super(const {});

  PayPalCheckoutView? view(String id) => state[id];

  /// Enregistre le checkout préparé par l'agent (sans écraser un état plus récent).
  void seed(Map<String, dynamic> checkout) {
    final id = checkout['checkout_id']?.toString();
    if (id == null || state.containsKey(id)) return;
    state = {...state, id: PayPalCheckoutView(data: checkout)};
  }

  void _put(PayPalCheckoutView v) => state = {...state, v.id: v};

  Future<void> _run(String id, String op, Future<Map<String, dynamic>> Function() call) async {
    final current = state[id];
    if (current == null || current.busy != null) return; // une seule opération à la fois
    _put(current.copyWith(busy: op, clearError: true));
    try {
      final data = await call();
      final previous = state[id]!.data;
      // Les réponses d'action n'incluent pas toujours le journal d'audit : on conserve le dernier connu
      if (!data.containsKey('events') && previous.containsKey('events')) {
        data['events'] = previous['events'];
      }
      _put(PayPalCheckoutView(data: data));
      _notifyAgent(state[id]!, op);
    } on PayPalApiException catch (e) {
      final base = state[id]!;
      _put(base.copyWith(
        data: e.checkout ?? base.data,
        clearBusy: true,
        errorCode: e.code,
        errorMessage: e.message,
      ));
    } on TimeoutException {
      _put(state[id]!.copyWith(
        clearBusy: true,
        errorCode: 'TIMEOUT',
        errorMessage: 'SIKA did not get an answer in time. The last verified status is shown — check again before retrying.',
      ));
    } on SocketException {
      _put(state[id]!.copyWith(
        clearBusy: true,
        errorCode: 'NETWORK',
        errorMessage: 'No connection to the SIKA server. Nothing new was sent to PayPal.',
      ));
    } catch (e) {
      debugPrint('[SIKA PAY] $op failed: $e');
      _put(state[id]!.copyWith(clearBusy: true, errorCode: 'UNEXPECTED', errorMessage: e.toString()));
    }
  }

  /// Revérification (lecture seule) du statut auprès de PayPal via le backend.
  Future<void> refresh(String id, {bool sync = true}) async {
    if (!state.containsKey(id)) {
      try {
        final data = await _api.getPayPalCheckout(id, sync: sync);
        _put(PayPalCheckoutView(data: data));
      } catch (e) {
        debugPrint('[SIKA PAY] initial load failed: $e');
      }
      return;
    }
    await _run(id, 'refresh', () => _api.getPayPalCheckout(id, sync: sync));
  }

  /// Confirmation explicite de l'utilisateur : création de la commande PayPal puis ouverture de PayPal.
  Future<void> confirmAndOpenPayPal(String id) async {
    final v = state[id];
    if (v == null) return;
    await _run(id, 'confirm', () => _api.confirmPayPalCheckout(id, v.detailsHash));
    await openApproval(id);
  }

  Future<bool> openApproval(String id) async {
    final url = state[id]?.paypal['approve_url']?.toString();
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse(url);
    // Défense en profondeur : on n'ouvre que des pages PayPal en HTTPS
    if (uri.scheme != 'https' || !(uri.host == 'paypal.com' || uri.host.endsWith('.paypal.com'))) {
      _put(state[id]!.copyWith(errorCode: 'INVALID_APPROVAL_LINK', errorMessage: 'Unexpected approval link. It was not opened.'));
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> capture(String id) => _run(id, 'capture', () => _api.capturePayPalCheckout(id));

  Future<void> cancel(String id) => _run(id, 'cancel', () => _api.cancelPayPalCheckout(id));

  void _notifyAgent(PayPalCheckoutView v, String op) {
    if (op == 'refresh' && !v.isTerminal && v.status != 'APPROVED') return;
    _ref.read(sikaProvider.notifier).reportPayPalOutcome(v.data);
    if (v.isTerminal) _ref.invalidate(paypalHistoryProvider);
  }
}

final paypalCheckoutsProvider =
    StateNotifierProvider<PayPalCheckoutsNotifier, Map<String, PayPalCheckoutView>>((ref) {
  return PayPalCheckoutsNotifier(ref.watch(apiServiceProvider), ref);
});

/// Historique SIKA Pay (statuts enregistrés côté serveur).
final paypalHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final rows = await api.listPayPalCheckouts(limit: 30);
  return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Configuration sandbox exposée par le backend (aucun secret).
final paypalStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).getPayPalStatus();
});

/// Autorisation accordée à l'agent (mode hybride), telle que le serveur la connaît.
final agentAuthorizationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).getAgentAuthorization();
});

/// Alertes de prix sur des produits du web (statuts du serveur, déclenchées par les webhooks Channel3).
final priceWatchesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).listPriceWatches();
});
