import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class PaymentMethod {
  final String id;
  final String type; // 'card', 'mobile_money'
  final String title; // e.g. "Visa terminant par 4242"
  final String subtitle; // e.g. "Expire 12/28"
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  PaymentMethod copyWith({
    String? id,
    String? type,
    String? title,
    String? subtitle,
    bool? isDefault,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isDefault: isDefault ?? this.isDefault,
    );
  }
  
  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      subtitle: json['subtitle'],
      isDefault: json['is_default'] ?? false,
    );
  }
}

class PaymentState {
  final List<PaymentMethod> methods;
  final bool isLoading;

  PaymentState({
    this.methods = const [],
    this.isLoading = false,
  });

  PaymentState copyWith({
    List<PaymentMethod>? methods,
    bool? isLoading,
  }) {
    return PaymentState(
      methods: methods ?? this.methods,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final ApiService _apiService;

  PaymentNotifier(this._apiService) : super(PaymentState()) {
    loadMethods();
  }
  
  Future<void> loadMethods() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _apiService.getPaymentMethods();
      final methods = data.map((json) => PaymentMethod.fromJson(json)).toList();
      state = state.copyWith(methods: methods, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addPaymentMethod(PaymentMethod method) async {
    try {
      final res = await _apiService.addPaymentMethod({
        'type': method.type,
        'title': method.title,
        'subtitle': method.subtitle,
        'is_default': method.isDefault,
      });
      final newMethod = PaymentMethod.fromJson(res);
      
      // If new method is default, unset default on others
      List<PaymentMethod> currentMethods = state.methods;
      if (newMethod.isDefault) {
        currentMethods = currentMethods.map((m) => m.copyWith(isDefault: false)).toList();
      }

      state = state.copyWith(
        methods: [...currentMethods, newMethod],
      );
    } catch (e) {
      // Error handling
    }
  }

  Future<void> removePaymentMethod(String id) async {
    try {
      await _apiService.deletePaymentMethod(id);
      state = state.copyWith(
        methods: state.methods.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      // Error handling
    }
  }
  
  Future<void> setDefault(String id) async {
    try {
      await _apiService.setDefaultPaymentMethod(id);
      state = state.copyWith(
        methods: state.methods.map((m) {
          return m.copyWith(isDefault: m.id == id);
        }).toList(),
      );
    } catch (e) {
      // Error handling
    }
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  // In a real app we'd get the auth token via a provider if ApiService didn't pull it from a static config or local storage.
  // Assuming ApiService handles tokens via secureStorage.
  return PaymentNotifier(ApiService());
});
