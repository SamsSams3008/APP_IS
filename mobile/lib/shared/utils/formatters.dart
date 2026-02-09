import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _compact = NumberFormat.compact();

String formatMoney(double value) {
  return _currency.format(value);
}

String formatNumber(int value) {
  if (value >= 1000) return _compact.format(value);
  return value.toString();
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}
