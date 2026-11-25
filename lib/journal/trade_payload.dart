import 'field_specs.dart';

/// Turns API validation issues into {field: message}. Handles both shapes:
/// {path: [..], message} from input checks and {path: 'x', message} from DB rules.
Map<String, String> fieldErrors(List<dynamic> issues) {
  final out = <String, String>{};
  for (final raw in issues) {
    if (raw is! Map) continue;
    final path = raw['path'];
    final key = path is List ? path.join('.') : (path?.toString() ?? '');
    out.putIfAbsent(key, () => raw['message']?.toString() ?? 'Invalid value');
  }
  return out;
}

/// Client-side checks that mirror the backend rules, so the user sees problems
/// before a round trip.
Map<String, String> validateTrade(Map<String, dynamic> v) {
  final errors = <String, String>{};
  final status = v['status'];

  void required(String key) {
    if (v[key] == null) errors[key] = 'Required';
  }

  required('pair');
  required('direction');
  if (status == 'open' || status == 'closed') {
    required('entryPrice');
    required('stopLoss');
    required('entryTime');
  }
  if (status == 'closed') {
    required('exitPrice');
    required('exitTime');
  }

  const positive = {'entryPrice', 'stopLoss', 'takeProfit', 'exitPrice', 'positionSize'};
  for (final spec in tradeFields) {
    final value = v[spec.key];
    if (value == null || errors.containsKey(spec.key)) continue;
    if (value is num) {
      if (positive.contains(spec.key) && value <= 0) {
        errors[spec.key] = 'Must be above 0';
      } else if (spec.min != null && value < spec.min!) {
        errors[spec.key] = 'Minimum is ${spec.min}';
      } else if (spec.max != null && value > spec.max!) {
        errors[spec.key] = 'Maximum is ${spec.max}';
      }
    }
    if (spec.kind == FieldKind.url && value is String) {
      final uri = Uri.tryParse(value);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
        errors[spec.key] = 'Enter a full http(s) link';
      }
    }
  }
  return errors;
}

/// Builds the request body for [keys] only. Empty values are omitted, numbers
/// are real numbers, dates are UTC ISO strings, and read-only fields are never
/// included.
Map<String, dynamic> buildPayload(Map<String, dynamic> values, Iterable<String> keys) {
  final out = <String, dynamic>{};
  for (final key in keys) {
    if (readOnlyKeys.contains(key)) continue;
    final v = values[key];
    if (v == null) continue;

    if (key == 'status' || key == 'direction') {
      out[key] = v.toString();
      continue;
    }
    if (key == 'pair') {
      final pair = v.toString().trim().toUpperCase();
      if (pair.isNotEmpty) out[key] = pair;
      continue;
    }

    final spec = specByKey[key];
    if (spec == null) continue;
    switch (spec.kind) {
      case FieldKind.text:
      case FieldKind.longText:
      case FieldKind.choice:
      case FieldKind.url:
        final s = v.toString().trim();
        if (s.isNotEmpty) out[key] = s;
      case FieldKind.number:
        if (v is num && v.isFinite) out[key] = v.toDouble();
      case FieldKind.integer:
      case FieldKind.scale:
        if (v is num) out[key] = v.round();
      case FieldKind.dateTime:
        if (v is DateTime) out[key] = v.toUtc().toIso8601String();
      case FieldKind.tri:
        if (v is bool) out[key] = v;
      case FieldKind.tags:
        if (v is List && v.isNotEmpty) out[key] = v.map((e) => e.toString()).toList();
    }
  }
  return out;
}
