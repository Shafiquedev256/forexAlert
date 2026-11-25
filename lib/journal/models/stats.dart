double? _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

class Summary {
  const Summary({
    required this.trades,
    required this.wins,
    required this.losses,
    this.winRate,
    this.avgWinR,
    this.avgLossR,
    this.expectancyR,
    this.profitFactor,
    required this.totalR,
    this.stdDevR,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        trades: _i(j['trades']),
        wins: _i(j['wins']),
        losses: _i(j['losses']),
        winRate: _d(j['winRate']),
        avgWinR: _d(j['avgWinR']),
        avgLossR: _d(j['avgLossR']),
        expectancyR: _d(j['expectancyR']),
        profitFactor: _d(j['profitFactor']),
        totalR: _d(j['totalR']) ?? 0,
        stdDevR: _d(j['stdDevR']),
      );

  static const empty = Summary(trades: 0, wins: 0, losses: 0, totalR: 0);

  final int trades;
  final int wins;
  final int losses;
  final double? winRate;
  final double? avgWinR;
  final double? avgLossR;
  final double? expectancyR;
  final double? profitFactor;
  final double totalR;
  final double? stdDevR;
}

class SegmentRow {
  const SegmentRow(this.key, this.summary);

  final String key;
  final Summary summary;
}

class EquityPoint {
  const EquityPoint(this.date, this.cumulativeR);

  final String? date;
  final double cumulativeR;
}

class RollingPoint {
  const RollingPoint(this.tradeNumber, this.winRate, this.expectancyR);

  final int tradeNumber;
  final double winRate;
  final double expectancyR;
}

class WeeklyPoint {
  const WeeklyPoint(this.week, this.totalR);

  final String week;
  final double totalR;
}

class Stats {
  const Stats({
    required this.overall,
    required this.maxLosingStreak,
    required this.maxDrawdownR,
    this.sampleWarning,
    this.adherencePct,
    this.profitableWeeksPct,
    this.equityCurve = const [],
    this.rollingWindow = 20,
    this.rolling = const [],
    this.weekly = const [],
    this.segments = const {},
  });

  factory Stats.fromJson(Map<String, dynamic> j) {
    final overall = (j['overall'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rolling = (j['rolling'] as Map?)?.cast<String, dynamic>() ?? const {};
    final segs = (j['segments'] as Map?)?.cast<String, dynamic>() ?? const {};

    List<T> mapList<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
        raw is List ? raw.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];

    return Stats(
      overall: Summary.fromJson(overall),
      maxLosingStreak: _i(overall['maxLosingStreak']),
      maxDrawdownR: _d(overall['maxDrawdownR']) ?? 0,
      sampleWarning: j['sampleWarning']?.toString(),
      adherencePct: _d(j['adherencePct']),
      profitableWeeksPct: _d(j['profitableWeeksPct']),
      equityCurve: mapList(j['equityCurve'], (e) => EquityPoint(e['date']?.toString(), _d(e['cumulativeR']) ?? 0)),
      rollingWindow: _i(rolling['window']) == 0 ? 20 : _i(rolling['window']),
      rolling: mapList(
        rolling['points'],
        (e) => RollingPoint(_i(e['tradeNumber']), _d(e['winRate']) ?? 0, _d(e['expectancyR']) ?? 0),
      ),
      weekly: mapList(j['weekly'], (e) => WeeklyPoint(e['week'].toString(), _d(e['totalR']) ?? 0)),
      segments: {
        for (final entry in segs.entries)
          entry.key: mapList(
            entry.value,
            (e) => SegmentRow(e['key']?.toString() ?? '-', Summary.fromJson(e)),
          ),
      },
    );
  }

  final Summary overall;
  final int maxLosingStreak;
  final double maxDrawdownR;
  final String? sampleWarning;
  final double? adherencePct;
  final double? profitableWeeksPct;
  final List<EquityPoint> equityCurve;
  final int rollingWindow;
  final List<RollingPoint> rolling;
  final List<WeeklyPoint> weekly;
  final Map<String, List<SegmentRow>> segments;
}
