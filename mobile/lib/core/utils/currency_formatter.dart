import 'package:intl/intl.dart';

/// CurrencyFormatter — Formats financial amounts into FCFA string representation.
class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'fr_FR');

  static String format(num amount, {String currency = 'FCFA'}) {
    final formatted = _formatter.format(amount).replaceAll(',', ' ');
    return '$formatted $currency';
  }
}
