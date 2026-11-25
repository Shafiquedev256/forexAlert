const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Local date and time, e.g. "24 Nov 2026, 14:05". Missing values show "-".
String fmtDateTime(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  return '${_two(l.day)} ${_months[l.month - 1]} ${l.year}, ${_two(l.hour)}:${_two(l.minute)}';
}

String fmtDate(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  return '${_two(l.day)} ${_months[l.month - 1]} ${l.year}';
}

/// R multiples: "+1.50R", "-1.00R", "0.00R", or "-" when missing.
String fmtR(double? r) {
  if (r == null) return '-';
  if (r.abs() < 0.005) return '0.00R';
  return '${r > 0 ? '+' : ''}${r.toStringAsFixed(2)}R';
}

String fmtNum(double? v, {int decimals = 2}) => v == null ? '-' : v.toStringAsFixed(decimals);

/// Percentages with one decimal. [v] must already be 0-100.
String fmtPct(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)}%';

/// The API may return win rate as 0-1 or 0-100; normalise to 0-100.
double? pctFromFraction(double? v) => v == null ? null : (v <= 1 ? v * 100 : v);

int priceDecimals(String pair) {
  final p = pair.toUpperCase();
  if (p.contains('JPY')) return 3;
  if (p.contains('XAU') || p.contains('BTC')) return 2;
  return 5;
}

String fmtPrice(String pair, double? v) => v == null ? '-' : v.toStringAsFixed(priceDecimals(pair));

/// "on_time" -> "On time"
String titleCase(String s) {
  final t = s.replaceAll('_', ' ').trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Display label for a stored option value.
String labelFor(String key, String option) {
  if (key == 'timeframe') return option.toUpperCase();
  if (option == 'newyork') return 'New York';
  return titleCase(option);
}
