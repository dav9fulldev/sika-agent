import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppCurrency { fcfa, usd, eur, gbp }

extension AppCurrencyExtension on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.fcfa:
        return 'FCFA';
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.gbp:
        return 'GBP';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.fcfa:
        return 'FCFA';
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.gbp:
        return '£';
    }
  }

  double get rateFromFcfa {
    switch (this) {
      case AppCurrency.fcfa:
        return 1.0;
      case AppCurrency.usd:
        return 1.0 / 600.0;
      case AppCurrency.eur:
        return 1.0 / 655.957;
      case AppCurrency.gbp:
        return 1.0 / 770.0;
    }
  }
}

class CurrencyNotifier extends StateNotifier<AppCurrency> {
  CurrencyNotifier() : super(AppCurrency.fcfa);

  void setCurrency(AppCurrency currency) {
    state = currency;
  }

  void setCurrencyByCode(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
      case '\$':
        state = AppCurrency.usd;
        break;
      case 'EUR':
      case '€':
        state = AppCurrency.eur;
        break;
      case 'GBP':
      case '£':
        state = AppCurrency.gbp;
        break;
      default:
        state = AppCurrency.fcfa;
        break;
    }
  }

  /// Formats an amount given in base FCFA to the active currency with exchange conversion
  String format(double amountInFcfa) {
    final converted = amountInFcfa * state.rateFromFcfa;
    if (state == AppCurrency.fcfa) {
      final intVal = converted.round();
      final formattedStr = _formatIntegerWithSpaces(intVal);
      return '$formattedStr FCFA';
    } else {
      return '${state.symbol}${converted.toStringAsFixed(2)}';
    }
  }

  String _formatIntegerWithSpaces(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, AppCurrency>((ref) {
  return CurrencyNotifier();
});
