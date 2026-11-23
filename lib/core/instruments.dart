/// Where a price comes from.
enum PriceSource { binance, twelveData }

/// A tradable instrument. To add a pair, add one line to [instruments].
class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.source,
    required this.providerSymbol,
    this.decimals = 5,
  });

  /// Shown to the user and used as the stable key, e.g. "XAU/USD".
  final String symbol;
  final String name;
  final PriceSource source;

  /// What the price API expects, e.g. "BTCUSDT" on Binance.
  final String providerSymbol;
  final int decimals;

  String format(double value) => formatPrice(value, decimals);
}

const List<Instrument> instruments = [
  Instrument(symbol: 'XAU/USD', name: 'Gold', source: PriceSource.twelveData, providerSymbol: 'XAU/USD', decimals: 2),
  // Binance quotes BTC in USDT, which tracks USD closely.
  Instrument(symbol: 'BTC/USD', name: 'Bitcoin', source: PriceSource.binance, providerSymbol: 'BTCUSDT', decimals: 2),
  Instrument(symbol: 'EUR/USD', name: 'Euro / US Dollar', source: PriceSource.twelveData, providerSymbol: 'EUR/USD'),
  Instrument(symbol: 'GBP/USD', name: 'Pound / US Dollar', source: PriceSource.twelveData, providerSymbol: 'GBP/USD'),
  Instrument(symbol: 'USD/JPY', name: 'US Dollar / Yen', source: PriceSource.twelveData, providerSymbol: 'USD/JPY', decimals: 3),
  Instrument(symbol: 'USD/CHF', name: 'US Dollar / Swiss Franc', source: PriceSource.twelveData, providerSymbol: 'USD/CHF'),
  Instrument(symbol: 'AUD/USD', name: 'Australian Dollar / US Dollar', source: PriceSource.twelveData, providerSymbol: 'AUD/USD'),
  Instrument(symbol: 'USD/CAD', name: 'US Dollar / Canadian Dollar', source: PriceSource.twelveData, providerSymbol: 'USD/CAD'),
  Instrument(symbol: 'NZD/USD', name: 'New Zealand Dollar / US Dollar', source: PriceSource.twelveData, providerSymbol: 'NZD/USD'),
];

Instrument instrumentFor(String symbol) =>
    instruments.firstWhere((i) => i.symbol == symbol, orElse: () => instruments.first);

/// Forex and gold are closed from Friday 22:00 UTC to Sunday 22:00 UTC.
/// The app skips those requests to save free-plan API credits.
bool isForexMarketOpen(DateTime nowUtc) {
  final minutes = nowUtc.hour * 60 + nowUtc.minute;
  switch (nowUtc.weekday) {
    case DateTime.saturday:
      return false;
    case DateTime.friday:
      return minutes < 22 * 60;
    case DateTime.sunday:
      return minutes >= 22 * 60;
    default:
      return true;
  }
}

/// 2650.5 -> "2,650.50"
String formatPrice(double value, int decimals) {
  final parts = value.toStringAsFixed(decimals).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}
