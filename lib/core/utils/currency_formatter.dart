import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static double parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String format(dynamic amount) {
    if (amount == null) return 'Rp 0';
    if (amount is num) return _formatter.format(amount);
    if (amount is String) {
      final parsed = double.tryParse(amount);
      if (parsed != null) return _formatter.format(parsed);
    }
    return 'Rp 0';
  }
}
