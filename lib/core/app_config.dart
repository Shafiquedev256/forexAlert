/// Tunable constants in one place.
class AppConfig {
  AppConfig._();

  /// BTC (Binance) refresh interval.
  static const int cryptoIntervalSec = 10;

  /// Twelve Data free plan limits.
  static const int freePlanCreditsPerDay = 800;
  static const int freePlanCreditsPerMinute = 8;

  /// Segments with fewer closed trades than this are flagged "low sample".
  static const int lowSampleTrades = 30;
}

/// Seconds between gold/forex checks.
///
/// [setting] 0 means "Auto": spread the free plan's daily credits over 24h,
/// which is about 108 seconds per watched symbol.
int effectiveForexIntervalSec(int setting, int symbolCount) {
  if (setting > 0) return setting;
  final safe = (86400 * (symbolCount < 1 ? 1 : symbolCount) / AppConfig.freePlanCreditsPerDay).ceil();
  return safe < 10 ? 10 : safe;
}
