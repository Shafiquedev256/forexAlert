import 'package:flutter/foundation.dart';

import '../core/options.dart';
import '../services/storage.dart';
import 'journal_api.dart';
import 'models/trade.dart';
import 'trade_payload.dart';

class SaveResult {
  const SaveResult.ok(Trade this.trade)
      : fieldErrors = const {},
        error = null;

  const SaveResult.failed({this.fieldErrors = const {}, this.error}) : trade = null;

  final Trade? trade;
  final Map<String, String> fieldErrors;
  final String? error;

  bool get ok => trade != null;
}

/// Owns the API client and tells screens when to reload (after any write or
/// when the connection settings change).
class JournalController extends ChangeNotifier {
  JournalController(this.storage) : api = JournalApi(storage);

  final AppStorage storage;
  final JournalApi api;

  bool get configured => api.isConfigured;
  String get baseUrl => storage.journalBaseUrl;
  String get apiKey => storage.journalApiKey;

  List<String> get setupOptions => [...defaultSetups, ...storage.customSetups.where((s) => !defaultSetups.contains(s))];

  /// Call after anything that changes server data or connection settings.
  void refresh() => notifyListeners();

  Future<void> saveConnection(String baseUrl, String apiKey) async {
    await storage.setJournalConnection(baseUrl: baseUrl, apiKey: apiKey);
    refresh();
  }

  Future<void> addSetup(String setup) async {
    await storage.addCustomSetup(setup.trim().toLowerCase());
    notifyListeners();
  }

  Future<String> testConnection() async {
    try {
      final page = await api.listTrades({'limit': '1'});
      return 'Connected. ${page.total} trade${page.total == 1 ? '' : 's'} in your journal.';
    } on ApiException catch (e) {
      return friendly(e);
    }
  }

  Future<SaveResult> create(Map<String, dynamic> payload) => _save(() => api.createTrade(payload));

  Future<SaveResult> update(String id, Map<String, dynamic> payload) =>
      _save(() => api.updateTrade(id, payload));

  Future<SaveResult> _save(Future<Trade> Function() call) async {
    try {
      final trade = await call();
      refresh();
      return SaveResult.ok(trade);
    } on ApiException catch (e) {
      if (e.status == 400 && e.issues.isNotEmpty) {
        return SaveResult.failed(fieldErrors: fieldErrors(e.issues));
      }
      return SaveResult.failed(error: friendly(e));
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> delete(String id) async {
    try {
      await api.deleteTrade(id);
      refresh();
      return null;
    } on ApiException catch (e) {
      return friendly(e);
    }
  }

  static String friendly(ApiException e) {
    if (e.isUnauthorized) return 'The API key was rejected. Check it in Settings.';
    if (e.isNotFound) return 'Not found.';
    return e.message;
  }
}
