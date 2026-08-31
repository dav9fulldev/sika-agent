import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppCurrency { fcfa, usd, eur, gbp, unknown }

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
      case AppCurrency.unknown:
        return '';
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
      case AppCurrency.unknown:
        return '';
    }
  }

  // CRITICAL FINAL ARCHITECTURE: DO NOT INVENT EXCHANGE RATES
  // If no authoritative exchange rate service exists, return 1.0
  // and do NOT fabricate fixed rates like 1 USD = 600 XOF.
  double get rateFromFcfa {
    switch (this) {
      case AppCurrency.fcfa:
        return 1.0;
      default:
        // No authoritative conversion service available. Refuse conversion by returning 1.0
        // The UI will detect this and fallback to XOF (FCFA) to avoid misleading the user.
        return 1.0;
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
        state = AppCurrency.unknown;
        break;
    }
  }

  /// Formats an amount. If the currency is unknown, it refuses to format a fake currency.
  String format(double amount, {String? baseCurrency}) {
    if (state == AppCurrency.unknown && baseCurrency == null) {
      return '—';
    }
    
    // If we are in FCFA, or if conversion is unavailable (rate == 1.0 for non-FCFA),
    // we must fallback to the wallet's true currency (or baseCurrency if provided)
    // to avoid displaying fake converted values.
    if (state == AppCurrency.fcfa || state == AppCurrency.unknown || state.rateFromFcfa == 1.0) {
      final intVal = amount.round();
      final formattedStr = _formatIntegerWithSpaces(intVal);
      final suffix = baseCurrency ?? 'FCFA';
      return '$formattedStr $suffix'.trim();
    } else {
      final converted = amount * state.rateFromFcfa;
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
