/// Same formulas as the server, used for live previews in the form.
/// The server value is the source of truth after saving.

double? plannedRR(double? entry, double? stop, double? takeProfit) {
  if (entry == null || stop == null || takeProfit == null) return null;
  final risk = (entry - stop).abs();
  if (risk == 0) return null;
  return (takeProfit - entry).abs() / risk;
}

double? realizedR(String? direction, double? entry, double? stop, double? exit) {
  if (entry == null || stop == null || exit == null) return null;
  final risk = (entry - stop).abs();
  if (risk == 0) return null;
  final move = direction == 'short' ? entry - exit : exit - entry;
  return move / risk;
}
