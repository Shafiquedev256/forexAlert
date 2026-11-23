import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/instruments.dart';

class PriceException implements Exception {
  PriceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the free price APIs over HTTPS only. No identifiers, cookies or
/// custom headers are sent; the providers only see the request itself.
class PriceService {
  PriceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);
  static const _binanceHosts = ['api.binance.com', 'data-api.binance.vision'];

  Future<Map<String, double>> fetchBinance(List<Instrument> list) async {
    final out = <String, double>{};
    for (final i in list) {
      out[i.symbol] = await _binanceOne(i.providerSymbol);
    }
    return out;
  }

  Future<double> _binanceOne(String providerSymbol) async {
    Object? lastError;
    for (final host in _binanceHosts) {
      try {
        final res = await _client
            .get(Uri.https(host, '/api/v3/ticker/price', {'symbol': providerSymbol}))
            .timeout(_timeout);
        if (res.statusCode != 200) throw PriceException('Binance error ${res.statusCode}');
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return double.parse(data['price'] as String);
      } catch (e) {
        lastError = e;
      }
    }
    throw PriceException('Binance unavailable ($lastError)');
  }

  /// One request for all symbols (costs one credit per symbol).
  Future<Map<String, double>> fetchTwelveData(List<Instrument> list, String apiKey) async {
    if (apiKey.isEmpty) {
      throw PriceException('Add your Twelve Data API key in Settings');
    }
    final uri = Uri.https('api.twelvedata.com', '/price', {
      'symbol': list.map((i) => i.providerSymbol).join(','),
      'apikey': apiKey,
    });
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw PriceException('Twelve Data error ${res.statusCode}');

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) throw PriceException('Unexpected price response');
    if (body['status'] == 'error') {
      throw PriceException(body['message']?.toString() ?? 'Twelve Data error');
    }

    final result = <String, double>{};
    if (list.length == 1 && body.containsKey('price')) {
      result[list.first.symbol] = double.parse(body['price'].toString());
      return result;
    }
    for (final i in list) {
      final entry = body[i.providerSymbol];
      if (entry is Map<String, dynamic> && entry['price'] != null) {
        result[i.symbol] = double.parse(entry['price'].toString());
      }
    }
    if (result.isEmpty) throw PriceException('No prices returned');
    return result;
  }
}
