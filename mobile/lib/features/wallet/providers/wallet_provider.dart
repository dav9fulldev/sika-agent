import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

class WalletState {
  final bool isLoading;
  final List<ConnectedWalletItem> wallets;
  final String? errorMessage;

  WalletState({
    this.isLoading = false,
    this.wallets = const [],
    this.errorMessage,
  });

  WalletState copyWith({
    bool? isLoading,
    List<ConnectedWalletItem>? wallets,
    String? errorMessage,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get totalBalanceFcfa {
    return wallets.fold(0.0, (sum, item) => sum + item.balance);
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiService _apiService;

  WalletNotifier(this._apiService) : super(WalletState()) {
    fetchWallets();
  }

  Future<void> fetchWallets() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiService.fetchMyWallets();
      final List rawList = res['wallets'] ?? [];
      final List<ConnectedWalletItem> items =
          rawList.map((e) => ConnectedWalletItem.fromJson(e)).toList();

      state = state.copyWith(isLoading: false, wallets: items);
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error fetching wallets: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du chargement des portefeuilles.',
      );
    }
  }

  Future<bool> connectNewWallet({
    required String provider,
    required String accountNumber,
    required String authMethod,
    double initialBalance = 10000.0,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.connectWallet(
        provider: provider,
        accountNumber: accountNumber,
        authMethod: authMethod,
        initialBalance: initialBalance,
      );
      await fetchWallets();
      return true;
    } catch (e) {
      debugPrint('[WALLET PROVIDER] Error connecting wallet: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> syncAllWallets() async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.syncWallets();
      await fetchWallets();
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
