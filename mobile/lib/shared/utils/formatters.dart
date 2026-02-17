import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _compact = NumberFormat.compact();

String formatMoney(double value) {
  return _currency.format(value);
}

/// Para ejes de gráficas: redondeado a 2 decimales y compacto (ej. 1.23K, $5.67).
String formatMoneyChart(double value) {
  if (value.abs() >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(2)}K';
  }
  return '\$${value.toStringAsFixed(2)}';
}

String formatNumber(int value) {
  if (value >= 1000) return _compact.format(value);
  return value.toString();
}

/// Para ejes de gráficas: números redondeados a 2 decimales y compactos.
String formatNumberChart(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return value.toString();
}

/// Cualquier número mostrado con exactamente 2 decimales (tablas, tooltips).
String formatDecimal(double value) {
  return value.toStringAsFixed(2);
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Nombres de países por código ISO 3166-1 alpha-2 (común en APIs).
const Map<String, String> _countryNames = {
  'US': 'Estados Unidos', 'MX': 'México', 'ES': 'España', 'AR': 'Argentina',
  'CO': 'Colombia', 'CL': 'Chile', 'PE': 'Perú', 'BR': 'Brasil', 'EC': 'Ecuador',
  'VE': 'Venezuela', 'BO': 'Bolivia', 'PY': 'Paraguay', 'UY': 'Uruguay', 'CR': 'Costa Rica',
  'PA': 'Panamá', 'GT': 'Guatemala', 'HN': 'Honduras', 'SV': 'El Salvador', 'NI': 'Nicaragua',
  'DO': 'Rep. Dominicana', 'PR': 'Puerto Rico', 'CU': 'Cuba', 'JM': 'Jamaica',
  'GB': 'Reino Unido', 'UK': 'Reino Unido', 'FR': 'Francia', 'DE': 'Alemania', 'IT': 'Italia',
  'CA': 'Canadá', 'AU': 'Australia', 'IN': 'India', 'CN': 'China', 'JP': 'Japón',
  'KR': 'Corea del Sur', 'RU': 'Rusia', 'PL': 'Polonia', 'NL': 'Países Bajos',
  'BE': 'Bélgica', 'PT': 'Portugal', 'GR': 'Grecia', 'TR': 'Turquía', 'ZA': 'Sudáfrica',
  'EG': 'Egipto', 'NG': 'Nigeria', 'KE': 'Kenia', 'ID': 'Indonesia', 'TH': 'Tailandia',
  'VN': 'Vietnam', 'PH': 'Filipinas', 'MY': 'Malasia', 'SG': 'Singapur',
};

/// Muestra nombre del país; si es null/vacío devuelve "Todos"; si no está en el mapa, el código.
String formatCountry(String? code) {
  if (code == null || code.trim().isEmpty) return 'Todos';
  final upper = code.trim().toUpperCase();
  return _countryNames[upper] ?? upper;
}
