import 'dart:convert';

/// When an alert should fire relative to its target.
enum AlertDirection {
  above('Above', 'Rises to', 'Rings when the price reaches or goes above the target.'),
  below('Below', 'Falls to', 'Rings when the price reaches or drops below the target.'),
  cross('Cross', 'Crosses', 'Rings when the price crosses the target in either direction.');

  const AlertDirection(this.short, this.verb, this.hint);
  final String short;
  final String verb;
  final String hint;
}

class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.target,
    required this.direction,
    required this.note,
    required this.armedAt,
    this.enabled = true,
    this.ringtonePath,
  });

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  final String id;
  final String symbol;
  final double target;
  final AlertDirection direction;
  final String note;
  final bool enabled;

  /// Custom ringtone for this alert; null means "use the default".
  final String? ringtonePath;

  /// Epoch ms when the alert was (re)armed. It is active again whenever this
  /// is newer than the time it last fired.
  final int armedAt;

  bool isActive(Map<String, int> fired) => enabled && (fired[id] ?? 0) < armedAt;

  /// When this alert last fired since being armed, or null if still waiting.
  int? firedAt(Map<String, int> fired) {
    final t = fired[id];
    return (t != null && t >= armedAt) ? t : null;
  }

  bool conditionMet(double? previous, double current) {
    switch (direction) {
      case AlertDirection.above:
        return current >= target;
      case AlertDirection.below:
        return current <= target;
      case AlertDirection.cross:
        if (previous == null) return false;
        return (previous < target && current >= target) ||
            (previous > target && current <= target);
    }
  }

  PriceAlert copyWith({bool? enabled, int? armedAt}) => PriceAlert(
        id: id,
        symbol: symbol,
        target: target,
        direction: direction,
        note: note,
        enabled: enabled ?? this.enabled,
        ringtonePath: ringtonePath,
        armedAt: armedAt ?? this.armedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'target': target,
        'direction': direction.name,
        'note': note,
        'enabled': enabled,
        'ringtone': ringtonePath,
        'armedAt': armedAt,
      };

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        target: (json['target'] as num).toDouble(),
        direction: AlertDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => AlertDirection.above,
        ),
        note: (json['note'] as String?) ?? '',
        enabled: (json['enabled'] as bool?) ?? true,
        ringtonePath: json['ringtone'] as String?,
        armedAt: (json['armedAt'] as int?) ?? 0,
      );

  static List<PriceAlert> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<PriceAlert> alerts) =>
      jsonEncode(alerts.map((a) => a.toJson()).toList());
}
