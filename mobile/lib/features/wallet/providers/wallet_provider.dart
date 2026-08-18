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

class WalletState {
  final bool isLoading;
  final List<ConnectedWalletItem> wallets;
  final List<WalletMovementItem> movements;
  final String? lastPerceptionMessage;
  final String? errorMessage;

  WalletState({
    this.isLoading = false,
    this.wallets = const [],
    this.movements = const [],
    this.lastPerceptionMessage,
    this.errorMessage,
  });

  WalletState copyWith({
    bool? isLoading,
    List<ConnectedWalletItem>? wallets,
    List<WalletMovementItem>? movements,
    String? lastPerceptionMessage,
    String? errorMessage,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      movements: movements ?? this.movements,
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

  WalletNotifier(this._apiService) : super(WalletState()) {
    fetchWallets();
    fetchMovements();
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
      await fetchMovements();
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
