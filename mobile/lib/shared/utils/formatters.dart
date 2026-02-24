import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _compact = NumberFormat.compact();

String formatMoney(double value) {
  return _currency.format(value);
}

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

String formatNumberChart(int value) {
  if (value >= 1000000) return '${(value / 1000000).toString()}M';
  if (value >= 1000) return '${(value / 1000).toString()}K';
  return value.toString();
}

String formatDecimal(double value) {
  return value.toStringAsFixed(2);
}

String formatPercent(double value) {
  return '${value.toStringAsFixed(2)}%';
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Nombres de países por código ISO 3166-1 alpha-2. Español.
const Map<String, String> _countryNamesEs = {
  'US': 'Estados Unidos', 'MX': 'México', 'ES': 'España', 'AR': 'Argentina',
  'CO': 'Colombia', 'CL': 'Chile', 'PE': 'Perú', 'BR': 'Brasil', 'EC': 'Ecuador',
  'VE': 'Venezuela', 'BO': 'Bolivia', 'PY': 'Paraguay', 'UY': 'Uruguay', 'CR': 'Costa Rica',
  'PA': 'Panamá', 'GT': 'Guatemala', 'HN': 'Honduras', 'SV': 'El Salvador', 'NI': 'Nicaragua',
  'DO': 'Rep. Dominicana', 'PR': 'Puerto Rico', 'CU': 'Cuba', 'JM': 'Jamaica', 'HT': 'Haití',
  'GB': 'Reino Unido', 'UK': 'Reino Unido', 'FR': 'Francia', 'DE': 'Alemania', 'IT': 'Italia',
  'CA': 'Canadá', 'AU': 'Australia', 'IN': 'India', 'CN': 'China', 'JP': 'Japón',
  'KR': 'Corea del Sur', 'RU': 'Rusia', 'PL': 'Polonia', 'NL': 'Países Bajos',
  'BE': 'Bélgica', 'PT': 'Portugal', 'GR': 'Grecia', 'TR': 'Turquía', 'ZA': 'Sudáfrica',
  'EG': 'Egipto', 'NG': 'Nigeria', 'KE': 'Kenia', 'ID': 'Indonesia', 'TH': 'Tailandia',
  'VN': 'Vietnam', 'PH': 'Filipinas', 'MY': 'Malasia', 'SG': 'Singapur',
  'AT': 'Austria', 'CH': 'Suiza', 'SE': 'Suecia', 'NO': 'Noruega', 'FI': 'Finlandia',
  'DK': 'Dinamarca', 'IE': 'Irlanda', 'CZ': 'República Checa', 'RO': 'Rumanía', 'HU': 'Hungría',
  'HR': 'Croacia', 'SK': 'Eslovaquia', 'BG': 'Bulgaria', 'UA': 'Ucrania', 'IL': 'Israel',
  'SA': 'Arabia Saudita', 'AE': 'Emiratos Árabes', 'PK': 'Pakistán', 'BD': 'Bangladés',
  'LK': 'Sri Lanka', 'NZ': 'Nueva Zelanda', 'HK': 'Hong Kong', 'TW': 'Taiwán',
  'LU': 'Luxemburgo', 'SI': 'Eslovenia', 'LT': 'Lituania', 'LV': 'Letonia',
  'EE': 'Estonia', 'RS': 'Serbia', 'QA': 'Catar', 'KW': 'Kuwait', 'OM': 'Omán', 'BH': 'Baréin',
  'JO': 'Jordania', 'LB': 'Líbano', 'IQ': 'Irak', 'IR': 'Irán', 'GH': 'Ghana', 'MA': 'Marruecos',
  'DZ': 'Argelia', 'TN': 'Túnez', 'LY': 'Libia',
};

/// Nombres de países en inglés.
const Map<String, String> _countryNamesEn = {
  'US': 'United States', 'MX': 'Mexico', 'ES': 'Spain', 'AR': 'Argentina',
  'CO': 'Colombia', 'CL': 'Chile', 'PE': 'Peru', 'BR': 'Brazil', 'EC': 'Ecuador',
  'VE': 'Venezuela', 'BO': 'Bolivia', 'PY': 'Paraguay', 'UY': 'Uruguay', 'CR': 'Costa Rica',
  'PA': 'Panama', 'GT': 'Guatemala', 'HN': 'Honduras', 'SV': 'El Salvador', 'NI': 'Nicaragua',
  'DO': 'Dominican Rep.', 'PR': 'Puerto Rico', 'CU': 'Cuba', 'JM': 'Jamaica', 'HT': 'Haiti',
  'GB': 'United Kingdom', 'UK': 'United Kingdom', 'FR': 'France', 'DE': 'Germany', 'IT': 'Italy',
  'CA': 'Canada', 'AU': 'Australia', 'IN': 'India', 'CN': 'China', 'JP': 'Japan',
  'KR': 'South Korea', 'RU': 'Russia', 'PL': 'Poland', 'NL': 'Netherlands',
  'BE': 'Belgium', 'PT': 'Portugal', 'GR': 'Greece', 'TR': 'Turkey', 'ZA': 'South Africa',
  'EG': 'Egypt', 'NG': 'Nigeria', 'KE': 'Kenya', 'ID': 'Indonesia', 'TH': 'Thailand',
  'VN': 'Vietnam', 'PH': 'Philippines', 'MY': 'Malaysia', 'SG': 'Singapore',
  'AT': 'Austria', 'CH': 'Switzerland', 'SE': 'Sweden', 'NO': 'Norway', 'FI': 'Finland',
  'DK': 'Denmark', 'IE': 'Ireland', 'CZ': 'Czech Republic', 'RO': 'Romania', 'HU': 'Hungary',
  'HR': 'Croatia', 'SK': 'Slovakia', 'BG': 'Bulgaria', 'UA': 'Ukraine', 'IL': 'Israel',
  'SA': 'Saudi Arabia', 'AE': 'United Arab Emirates', 'PK': 'Pakistan', 'BD': 'Bangladesh',
  'LK': 'Sri Lanka', 'NZ': 'New Zealand', 'HK': 'Hong Kong', 'TW': 'Taiwan',
  'LU': 'Luxembourg', 'SI': 'Slovenia', 'LT': 'Lithuania', 'LV': 'Latvia',
  'EE': 'Estonia', 'RS': 'Serbia', 'QA': 'Qatar', 'KW': 'Kuwait', 'OM': 'Oman', 'BH': 'Bahrain',
  'JO': 'Jordan', 'LB': 'Lebanon', 'IQ': 'Iraq', 'IR': 'Iran', 'GH': 'Ghana', 'MA': 'Morocco',
  'DZ': 'Algeria', 'TN': 'Tunisia', 'LY': 'Libya',
};

/// Muestra nombre del país según locale; si es null/vacío devuelve "All"/"Todos".
String formatCountry(String? code, [String? locale]) {
  if (code == null || code.trim().isEmpty) {
    return (locale == 'en') ? 'All' : 'Todos';
  }
  final upper = code.trim().toUpperCase();
  final names = (locale == 'en') ? _countryNamesEn : _countryNamesEs;
  return names[upper] ?? upper;
}

/// Códigos de país para filtros (si la API no devuelve país, el usuario puede elegir igual).
List<String> get countryCodesForFilter => _countryNamesEs.keys.toList()..sort();
