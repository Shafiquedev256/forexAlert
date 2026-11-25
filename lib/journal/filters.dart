/// Filters shared by the trades list, dashboard and analytics.
class TradeFilters {
  String? status;
  String? pair;
  String? direction;
  String? setup;
  String? session;
  String? timeframe;
  String? marketCondition;
  DateTime? from;
  DateTime? to;
  String sort = '-entryTime';

  TradeFilters copy() => TradeFilters()
    ..status = status
    ..pair = pair
    ..direction = direction
    ..setup = setup
    ..session = session
    ..timeframe = timeframe
    ..marketCondition = marketCondition
    ..from = from
    ..to = to
    ..sort = sort;

  /// Number of active filters, not counting status and sort.
  int get activeCount => [pair, direction, setup, session, timeframe, marketCondition, from, to]
      .where((v) => v != null)
      .length;

  void clear() {
    pair = direction = setup = session = timeframe = marketCondition = null;
    from = to = null;
  }

  Map<String, String> toQuery({bool includeStatus = true, bool includeSort = true, int? page, int? limit}) {
    final q = <String, String>{};
    void put(String key, String? v) {
      if (v != null && v.isNotEmpty) q[key] = v;
    }

    if (includeStatus) put('status', status);
    put('pair', pair);
    put('direction', direction);
    put('setup', setup);
    put('session', session);
    put('timeframe', timeframe);
    put('marketCondition', marketCondition);
    if (from != null) put('from', DateTime(from!.year, from!.month, from!.day).toUtc().toIso8601String());
    if (to != null) put('to', DateTime(to!.year, to!.month, to!.day, 23, 59, 59, 999).toUtc().toIso8601String());
    if (page != null) q['page'] = '$page';
    if (limit != null) q['limit'] = '$limit';
    if (includeSort) q['sort'] = sort;
    return q;
  }
}
