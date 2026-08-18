import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';

class ConnectedWalletItem {
  final String id;
  final String provider;
  final double balance;
  final String currency;
  final String accountNumber;
  final String authMethod;
  final bool isActive;
  final String lastSyncedAt;

  ConnectedWalletItem({
    required this.id,
    required this.provider,
    required this.balance,
    required this.currency,
    required this.accountNumber,
    required this.authMethod,
    required this.isActive,
    required this.lastSyncedAt,
  });

  factory ConnectedWalletItem.fromJson(Map<String, dynamic> json) {
    return ConnectedWalletItem(
      id: json['id'] ?? '',
      provider: json['provider'] ?? 'Wallet',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'XOF',
      accountNumber: json['account_number'] ?? '',
      authMethod: json['auth_method'] ?? 'OAUTH2_API',
      isActive: json['is_active'] ?? true,
      lastSyncedAt: json['last_synced_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider,
      'balance': balance,
      'currency': currency,
      'account_number': accountNumber,
      'auth_method': authMethod,
      'is_active': isActive,
      'last_synced_at': lastSyncedAt,
    };
  }
}

class WalletMovementItem {
  final String id;
  final String walletProvider;
  final String type;
  final double amount;
  final String currency;
  final String category;
  final String recipient;
  final String description;
  final String status;
  final String timestamp;

  WalletMovementItem({
    required this.id,
    required this.walletProvider,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.recipient,
    required this.description,
    required this.status,
    required this.timestamp,
  });

  factory WalletMovementItem.fromJson(Map<String, dynamic> json) {
    return WalletMovementItem(
      id: json['id'] ?? '',
      walletProvider: json['wallet_provider'] ?? 'Wave',
      type: json['type'] ?? 'payment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'XOF',
      category: json['category'] ?? 'Autre',
      recipient: json['recipient'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class CoffreItem {
  final int id;
  final String nom;
  final double solde;
  final double objectif;
  final String typeCoffre;
  final String statut;

  CoffreItem({
    required this.id,
    required this.nom,
    required this.solde,
    required this.objectif,
    required this.typeCoffre,
    required this.statut,
  });

  factory CoffreItem.fromJson(Map<String, dynamic> json) {
    return CoffreItem(
      id: json['id'] ?? 0,
      nom: json['nom'] ?? 'Coffre',
      solde: (json['solde'] as num?)?.toDouble() ?? 0.0,
      objectif: (json['objectif'] as num?)?.toDouble() ?? 0.0,
      typeCoffre: json['typeCoffre'] ?? 'EPARGNE',
      statut: json['statut'] ?? 'ACTIF',
    );
  }
}

class WalletState {
  final bool isLoading;
  final List<ConnectedWalletItem> wallets;
  final List<WalletMovementItem> movements;
  final List<CoffreItem> coffres;
  final String? pendingOtpSessionId;
  final String? lastPerceptionMessage;
  final String? errorMessage;

  WalletState({
    this.isLoading = false,
    this.wallets = const [],
    this.movements = const [],
    this.coffres = const [],
    this.pendingOtpSessionId,
    this.lastPerceptionMessage,
    this.errorMessage,
  });

  WalletState copyWith({
    bool? isLoading,
    List<ConnectedWalletItem>? wallets,
    List<WalletMovementItem>? movements,
    List<CoffreItem>? coffres,
    String? pendingOtpSessionId,
    String? lastPerceptionMessage,
    String? errorMessage,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      movements: movements ?? this.movements,
      coffres: coffres ?? this.coffres,
      pendingOtpSessionId: pendingOtpSessionId ?? this.pendingOtpSessionId,
      lastPerceptionMessage: lastPerceptionMessage ?? this.lastPerceptionMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get totalBalanceFcfa {
    return wallets.fold(0.0, (sum, item) => sum + item.balance);
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiService _apiService;
  static const String _cachedWalletsKey = 'sika_cached_enrolled_wallets';

  WalletNotifier(this._apiService) : super(WalletState()) {
    _init();
  }

  Future<void> _init() async {
    await loadCachedWallets();
    await fetchWallets();
    await fetchMovements();
    await fetchCoffres();
  }

  Future<void> loadCachedWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_cachedWalletsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final List<ConnectedWalletItem> cachedItems =
            decoded.map((e) => ConnectedWalletItem.fromJson(e)).toList();
        if (cachedItems.isNotEmpty) {
          state = state.copyWith(wallets: cachedItems);
          debugPrint('[WALLET CACHE] Loaded ${cachedItems.length} wallet(s) from device storage.');
        }
      }
    } catch (e) {
      debugPrint('[WALLET CACHE] Error loading cached wallets: $e');
    }
  }

  Future<void> saveCachedWallets(List<ConnectedWalletItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_cachedWalletsKey, jsonStr);
      debugPrint('[WALLET CACHE] Saved ${items.length} wallet(s) to device storage.');
    } catch (e) {
      debugPrint('[WALLET CACHE] Error saving cached wallets: $e');
    }
  }

  Future<void> fetchWallets() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiService.fetchMyWallets();
      final List rawList = res['wallets'] ?? [];
      final List<ConnectedWalletItem> items =
          rawList.map((e) => ConnectedWalletItem.fromJson(e)).toList();

      state = state.copyWith(isLoading: false, wallets: items);
      await saveCachedWallets(items);
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error fetching wallets: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du chargement des portefeuilles.',
      );
    }
  }

  Future<void> fetchMovements() async {
    try {
      final res = await _apiService.fetchWalletTransactionHistory();
      final List rawMovements = res['movements'] ?? [];
      final List<WalletMovementItem> items =
          rawMovements.map((e) => WalletMovementItem.fromJson(e)).toList();

      state = state.copyWith(movements: items);
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error fetching movements: $e');
    }
  }

  Future<void> fetchCoffres() async {
    try {
      final res = await _apiService.fetchUserCoffres();
      final List rawCoffres = res['coffres'] ?? [];
      final List<CoffreItem> items =
          rawCoffres.map((e) => CoffreItem.fromJson(e)).toList();

      state = state.copyWith(coffres: items);
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error fetching coffres: $e');
    }
  }

  Future<String?> initiateWalletConnection({
    required String provider,
    required String accountNumber,
    required String authMethod,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _apiService.connectWallet(
        provider: provider,
        accountNumber: accountNumber,
        authMethod: authMethod,
      );
      final sessionId = res['session_id'] as String?;
      state = state.copyWith(isLoading: false, pendingOtpSessionId: sessionId);
      return sessionId;
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error initiating OTP: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> verifyWalletOtp({
    required String sessionId,
    required String otpCode,
    required String provider,
    required String accountNumber,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _apiService.verifyWalletOtp(
        sessionId: sessionId,
        otpCode: otpCode,
        provider: provider,
        accountNumber: accountNumber,
      );

      if (res['wallet'] != null && res['wallet'] is Map) {
        final newWallet = ConnectedWalletItem.fromJson(Map<String, dynamic>.from(res['wallet']));
        final List<ConnectedWalletItem> updatedList = state.wallets
            .where((w) => w.accountNumber != newWallet.accountNumber || w.provider != newWallet.provider)
            .toList();
        updatedList.add(newWallet);
        state = state.copyWith(wallets: updatedList, isLoading: false, pendingOtpSessionId: null);
        await saveCachedWallets(updatedList);
      } else {
        state = state.copyWith(isLoading: false, pendingOtpSessionId: null);
      }

      await fetchWallets();
      await fetchMovements();
      return true;
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error verifying OTP: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> perceiveSmsNotification(String rawSmsText, {String sender = 'WAVE'}) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _apiService.perceiveSms(text: rawSmsText, sender: sender);
      final msg = res['message'] ?? 'SMS intercepté avec succès !';
      state = state.copyWith(isLoading: false, lastPerceptionMessage: msg);
      await fetchWallets();
      await fetchMovements();
      return true;
    } catch (e) {
      debugPrint('[WALLET PERCEPTION] Error perceiving SMS: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> connectNewWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
  }) async {
    final sessId = await initiateWalletConnection(
      provider: provider,
      accountNumber: accountNumber,
      authMethod: authMethod,
    );
    if (sessId != null) {
      return await verifyWalletOtp(
        sessionId: sessId,
        otpCode: "123456",
        provider: provider,
        accountNumber: accountNumber,
      );
    }
    return false;
  }

  Future<void> syncAllWallets() async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.syncWallets();
      await fetchWallets();
      await fetchMovements();
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error syncing wallets: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final apiService = ApiService();
  return WalletNotifier(apiService);
});
