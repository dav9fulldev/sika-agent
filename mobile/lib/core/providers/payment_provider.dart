import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  PaymentNotifier() : super(PaymentState());

  void addPaymentMethod(PaymentMethod method) {
    // If it's the first one, make it default
    final isFirst = state.methods.isEmpty;
    final newMethod = method.copyWith(isDefault: isFirst || method.isDefault);
    
    // If new method is default, unset default on others
    List<PaymentMethod> currentMethods = state.methods;
    if (newMethod.isDefault) {
      currentMethods = currentMethods.map((m) => m.copyWith(isDefault: false)).toList();
    }

    state = state.copyWith(
      methods: [...currentMethods, newMethod],
    );
  }

  void removePaymentMethod(String id) {
    state = state.copyWith(
      methods: state.methods.where((m) => m.id != id).toList(),
    );
  }
  
  void setDefault(String id) {
    state = state.copyWith(
      methods: state.methods.map((m) {
        return m.copyWith(isDefault: m.id == id);
      }).toList(),
    );
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier();
});
