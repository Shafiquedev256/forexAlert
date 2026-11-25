import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_alert.dart';
import '../models/quote.dart';
import '../models/ring_state.dart';

/// Everything is stored locally on the device. Each key has a single writer
/// (the UI or the background engine), so the two isolates never overwrite
/// each other's data.
class AppStorage {
  AppStorage._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppStorage> open() async => AppStorage._(await SharedPreferences.getInstance());

  /// Re-reads values written by the other isolate.
  Future<void> reload() => _prefs.reload();

  /// Changes whenever anything the UI shows changes.
  String get signature {
    final keys = _prefs.getKeys().toList()..sort();
    return keys.map((k) => '$k=${_prefs.get(k)}').join('|');
  }

  // ---- Written by the UI -------------------------------------------------

  static const _kAlerts = 'alerts';
  static const _kSleeping = 'sleeping';
  static const _kTheme = 'theme';
  static const _kInterval = 'forex_interval_sec';
  static const _kTone = 'default_tone';
  static const _kBundledTone = 'bundled_tone';
  static const _kApiKey = 'twelve_data_key';
  static const _kStopRequested = 'stop_requested_at';
  static const _buildTimeApiKey = String.fromEnvironment('TWELVE_DATA_API_KEY');

  List<PriceAlert> get alerts => PriceAlert.decodeList(_prefs.getString(_kAlerts));
  Future<void> saveAlerts(List<PriceAlert> v) => _prefs.setString(_kAlerts, PriceAlert.encodeList(v));

  bool get sleeping => _prefs.getBool(_kSleeping) ?? false;
  Future<void> setSleeping(bool v) => _prefs.setBool(_kSleeping, v);

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_kTheme),
        orElse: () => ThemeMode.system,
      );
  Future<void> setThemeMode(ThemeMode m) => _prefs.setString(_kTheme, m.name);

  /// Seconds between gold/forex checks. 0 = Auto (see effectiveForexIntervalSec).
  int get forexIntervalSec => _prefs.getInt(_kInterval) ?? 0;
  Future<void> setForexIntervalSec(int v) => _prefs.setInt(_kInterval, v);

  String? get defaultTonePath => _prefs.getString(_kTone);
  Future<void> setDefaultTonePath(String? v) =>
      v == null ? _prefs.remove(_kTone) : _prefs.setString(_kTone, v);

  /// Path of the built-in alarm copied to app storage (rewritten every launch).
  String? get bundledTonePath => _prefs.getString(_kBundledTone);
  Future<void> setBundledTonePath(String v) => _prefs.setString(_kBundledTone, v);

  /// The key typed in Settings, or the one baked in at build time.
  String get apiKey {
    final saved = _prefs.getString(_kApiKey);
    return (saved != null && saved.isNotEmpty) ? saved : _buildTimeApiKey;
  }

  Future<void> setApiKey(String v) => _prefs.setString(_kApiKey, v.trim());

  int get stopRequestedAt => _prefs.getInt(_kStopRequested) ?? 0;
  Future<void> requestStop() => _prefs.setInt(_kStopRequested, DateTime.now().millisecondsSinceEpoch);

  // ---- Journal connection (kept only in app-private storage) --------------

  static const defaultJournalUrl = 'https://forexjounalapi.vercel.app';
  static const _kJournalUrl = 'journal_base_url';
  static const _kJournalKey = 'journal_api_key';
  static const _kCustomSetups = 'custom_setups';

  String get journalBaseUrl {
    final saved = _prefs.getString(_kJournalUrl);
    return (saved == null || saved.isEmpty) ? defaultJournalUrl : saved;
  }

  String get journalApiKey => _prefs.getString(_kJournalKey) ?? '';

  Future<void> setJournalConnection({required String baseUrl, required String apiKey}) async {
    final cleaned = baseUrl.trim().replaceAll(RegExp(r'^[{\s]+|[}\s/]+$'), '');
    await _prefs.setString(_kJournalUrl, cleaned);
    await _prefs.setString(_kJournalKey, apiKey.trim());
  }

  List<String> get customSetups => _prefs.getStringList(_kCustomSetups) ?? const [];

  Future<void> addCustomSetup(String setup) async {
    if (setup.isEmpty || customSetups.contains(setup)) return;
    await _prefs.setStringList(_kCustomSetups, [...customSetups, setup]);
  }

  // ---- Written by the alert engine --------------------------------------

  static const _kQuotes = 'quotes';
  static const _kFired = 'fired';
  static const _kRing = 'ring';
  static const _kFeedError = 'feed_error';

  Map<String, Quote> get quotes {
    final raw = _prefs.getString(_kQuotes);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, Quote.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveQuotes(Map<String, Quote> v) =>
      _prefs.setString(_kQuotes, jsonEncode(v.map((k, q) => MapEntry(k, q.toJson()))));

  Map<String, int> get fired {
    final raw = _prefs.getString(_kFired);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveFired(Map<String, int> v) => _prefs.setString(_kFired, jsonEncode(v));

  RingState get ring {
    final raw = _prefs.getString(_kRing);
    if (raw == null) return RingState.idle;
    try {
      return RingState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return RingState.idle;
    }
  }

  Future<void> saveRing(RingState v) => _prefs.setString(_kRing, jsonEncode(v.toJson()));
  Future<void> clearRing() => _prefs.remove(_kRing);

  String? get feedError => _prefs.getString(_kFeedError);
  Future<void> setFeedError(String? v) async {
    if (v == feedError) return;
    if (v == null) {
      await _prefs.remove(_kFeedError);
    } else {
      await _prefs.setString(_kFeedError, v);
    }
  }
}
