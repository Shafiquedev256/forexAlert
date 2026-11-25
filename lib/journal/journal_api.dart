import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/storage.dart';
import 'models/stats.dart';
import 'models/trade.dart';

class ApiException implements Exception {
  ApiException(this.status, this.body, [String? message]) : message = message ?? _extract(body);

  /// 0 means the request never reached the server.
  final int status;
  final dynamic body;
  final String message;

  bool get isNotFound => status == 404;
  bool get isUnauthorized => status == 401;

  List<dynamic> get issues {
    final b = body;
    if (b is Map && b['issues'] is List) return b['issues'] as List;
    return const [];
  }

  static String _extract(dynamic body) {
    if (body is Map && body['error'] != null) return body['error'].toString();
    return 'Request failed';
  }

  @override
  String toString() => message;
}

/// Talks to the journal backend. The API key lives in app-private storage on
/// the device and is sent as the x-api-key header; it is never compiled in.
class JournalApi {
  JournalApi(this._storage, {http.Client? client}) : _client = client ?? http.Client();

  final AppStorage _storage;
  final http.Client _client;

  bool get isConfigured => _storage.journalApiKey.isNotEmpty && _storage.journalBaseUrl.isNotEmpty;

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final base = _storage.journalBaseUrl.replaceAll(RegExp(r'/+$'), '');
    var uri = Uri.parse('$base$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    try {
      final request = http.Request(method, uri)
        ..headers['content-type'] = 'application/json'
        ..headers['x-api-key'] = _storage.journalApiKey;
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _client.send(request).timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, decoded);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(0, null, 'The server took too long to respond');
    } catch (_) {
      throw ApiException(0, null, 'Could not reach the server. Check your connection.');
    }
  }

  Future<TradePage> listTrades(Map<String, String> query) async {
    final json = await _send('GET', '/api/trades', query: query) as Map<String, dynamic>;
    final data = (json['data'] as List?) ?? const [];
    return TradePage(
      items: data.map((e) => Trade((e as Map).cast<String, dynamic>())).toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? data.length,
    );
  }

  Future<Trade> getTrade(String id) async {
    final json = await _send('GET', '/api/trades/$id') as Map;
    return Trade(json.cast<String, dynamic>());
  }

  Future<Trade> createTrade(Map<String, dynamic> payload) async {
    final json = await _send('POST', '/api/trades', body: payload) as Map;
    return Trade(json.cast<String, dynamic>());
  }

  Future<Trade> updateTrade(String id, Map<String, dynamic> payload) async {
    final json = await _send('PATCH', '/api/trades/$id', body: payload) as Map;
    return Trade(json.cast<String, dynamic>());
  }

  Future<void> deleteTrade(String id) async {
    await _send('DELETE', '/api/trades/$id');
  }

  Future<Stats> stats(Map<String, String> query) async {
    final json = await _send('GET', '/api/stats', query: query) as Map;
    return Stats.fromJson(json.cast<String, dynamic>());
  }
}
