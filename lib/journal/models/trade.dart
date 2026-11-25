import '../field_specs.dart';

/// A trade as returned by the API. Keeps the raw JSON so new backend fields
/// are never lost, and exposes typed getters for what the UI needs.
class Trade {
  Trade(this.json);

  final Map<String, dynamic> json;

  String get id => json['_id'].toString();
  String get status => str('status') ?? 'planned';
  String get pair => str('pair') ?? '';
  String get direction => str('direction') ?? 'long';

  DateTime? get entryTime => date('entryTime');
  DateTime? get exitTime => date('exitTime');
  DateTime? get createdAt => date('createdAt');
  DateTime? get updatedAt => date('updatedAt');

  double? get entryPrice => dbl('entryPrice');
  double? get stopLoss => dbl('stopLoss');
  double? get takeProfit => dbl('takeProfit');
  double? get exitPrice => dbl('exitPrice');

  /// Calculated by the server. Null when not available (never 0).
  double? get plannedRR => dbl('plannedRR');
  double? get rMultiple => dbl('rMultiple');

  String? get setup => str('setup');
  String? get session => str('session');
  bool? get followedRules => flag('followedRules');

  String? str(String key) {
    final v = json[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  double? dbl(String key) {
    final v = json[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? integer(String key) => dbl(key)?.round();

  bool? flag(String key) {
    final v = json[key];
    return v is bool ? v : null;
  }

  DateTime? date(String key) {
    final v = json[key];
    if (v is! String) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  List<String> list(String key) {
    final v = json[key];
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  /// Initial values for the edit form, typed per field kind.
  Map<String, dynamic> toFormValues() {
    final out = <String, dynamic>{
      'status': status,
      'pair': pair,
      'direction': direction,
    };
    for (final spec in tradeFields) {
      dynamic value;
      switch (spec.kind) {
        case FieldKind.text:
        case FieldKind.longText:
        case FieldKind.choice:
        case FieldKind.url:
          value = str(spec.key);
        case FieldKind.number:
          value = dbl(spec.key);
        case FieldKind.integer:
        case FieldKind.scale:
          value = integer(spec.key);
        case FieldKind.dateTime:
          value = date(spec.key);
        case FieldKind.tri:
          value = flag(spec.key);
        case FieldKind.tags:
          final l = list(spec.key);
          value = l.isEmpty ? null : l;
      }
      if (value != null) out[spec.key] = value;
    }
    return out;
  }
}

class TradePage {
  const TradePage({required this.items, required this.page, required this.pages, required this.total});

  final List<Trade> items;
  final int page;
  final int pages;
  final int total;
}
