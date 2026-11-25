import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/instruments.dart';
import '../models/price_alert.dart';
import '../models/quote.dart';
import '../models/ring_state.dart';
import 'alarm_player.dart';
import 'alert_notifier.dart';
import 'price_service.dart';
import 'storage.dart';

/// The heart of the app: fetches prices, checks alerts, starts the alarm.
///
/// It runs once per second. On Android it lives in the foreground-service
/// isolate (so it keeps working with the screen locked); on iOS it runs in the
/// app itself.
class AlertEngine {
  AlertEngine({
    required this.storage,
    required this.prices,
    required this.alarm,
    required this.notifier,
  });

  /// Builds an engine for the background service isolate.
  static Future<AlertEngine> create() async {
    final notifier = AlertNotifier();
    await notifier.init();
    return AlertEngine(
      storage: await AppStorage.open(),
      prices: PriceService(),
      alarm: AlarmPlayer(),
      notifier: notifier,
    );
  }

  final AppStorage storage;
  final PriceService prices;
  final AlarmPlayer alarm;
  final AlertNotifier notifier;

  static const _staleQuoteMs = 10 * 60 * 1000;

  int _lastCrypto = 0;
  int _lastForex = 0;
  int _forexPausedUntil = 0;
  bool _busy = false;

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await storage.reload();
      if (storage.sleeping) {
        await _goQuiet();
        return;
      }
      await _syncRinging();
      await _poll();
    } catch (e) {
      debugPrint('AlertEngine tick failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> stopRinging() async {
    await alarm.stop();
    await notifier.cancelAll();
    await storage.clearRing();
  }

  Future<void> dispose() => alarm.dispose();

  // ---- Ringing -----------------------------------------------------------

  Future<void> _goQuiet() async {
    if (alarm.isRinging) {
      await alarm.stop();
      await notifier.cancelAll();
    }
    if (storage.ring.active) await storage.clearRing();
  }

  Future<void> _syncRinging() async {
    final ring = storage.ring;
    if (ring.active && storage.stopRequestedAt > ring.startedAt) {
      await stopRinging();
    } else if (ring.active && !alarm.isRinging) {
      // First start, or the service was restarted while ringing.
      final first = storage.alerts.where((a) => ring.alertIds.contains(a.id));
      await alarm.start(_toneFor(first.isEmpty ? null : first.first));
    } else if (!ring.active && alarm.isRinging) {
      await alarm.stop();
    }
  }

  String? _toneFor(PriceAlert? alert) {
    for (final path in [alert?.ringtonePath, storage.defaultTonePath, storage.bundledTonePath]) {
      if (path != null && File(path).existsSync()) return path;
    }
    return null; // AlarmPlayer falls back to the bundled asset
  }

  // ---- Price checks ------------------------------------------------------

  Future<void> _poll() async {
    final fired = storage.fired;
    final active = storage.alerts.where((a) => a.isActive(fired)).toList();
    if (active.isEmpty) return;

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final wanted = active.map((a) => instrumentFor(a.symbol)).toSet().toList();
    final updated = <String, double>{};
    String? error;
    var attempted = false;

    final crypto = wanted.where((i) => i.source == PriceSource.binance).toList();
    if (crypto.isNotEmpty && nowMs - _lastCrypto >= AppConfig.cryptoIntervalSec * 1000) {
      _lastCrypto = nowMs;
      attempted = true;
      try {
        updated.addAll(await prices.fetchBinance(crypto));
      } on PriceException catch (e) {
        error = e.message;
      } catch (_) {
        error = 'Network error, retrying';
      }
    }

    final forex = wanted.where((i) => i.source == PriceSource.twelveData).toList();
    final forexEveryMs = effectiveForexIntervalSec(storage.forexIntervalSec, forex.length) * 1000;
    if (forex.isNotEmpty &&
        isForexMarketOpen(now.toUtc()) &&
        nowMs >= _forexPausedUntil &&
        nowMs - _lastForex >= forexEveryMs) {
      _lastForex = nowMs;
      attempted = true;
      try {
        updated.addAll(await prices.fetchTwelveData(forex, storage.apiKey));
      } on PriceException catch (e) {
        error = e.message;
        if (e.rateLimited) {
          // Out of credits: stop asking until the limit resets.
          _forexPausedUntil = e.dailyLimit
              ? DateTime.utc(now.year, now.month, now.day + 1, 0, 5).millisecondsSinceEpoch
              : nowMs + 65 * 1000;
        }
      } catch (_) {
        error = 'Network error, retrying';
      }
    }

    if (updated.isNotEmpty) await _evaluate(active, updated, nowMs);
    if (attempted) await storage.setFeedError(error);
  }

  Future<void> _evaluate(List<PriceAlert> active, Map<String, double> updated, int nowMs) async {
    final previous = storage.quotes;
    final hits = <PriceAlert>[];

    for (final alert in active) {
      final current = updated[alert.symbol];
      if (current == null) continue;
      final prevQuote = previous[alert.symbol];
      final prev = (prevQuote != null && nowMs - prevQuote.ts < _staleQuoteMs) ? prevQuote.price : null;
      if (alert.conditionMet(prev, current)) hits.add(alert);
    }

    await storage.saveQuotes({
      ...previous,
      for (final e in updated.entries) e.key: Quote(price: e.value, ts: nowMs),
    });
    if (hits.isEmpty) return;

    await storage.saveFired({...storage.fired, for (final a in hits) a.id: nowMs});

    final ring = storage.ring;
    await storage.saveRing(RingState(
      alertIds: {...ring.alertIds, ...hits.map((a) => a.id)}.toList(),
      startedAt: ring.active ? ring.startedAt : nowMs,
    ));

    if (!alarm.isRinging) await alarm.start(_toneFor(hits.first));
    for (final alert in hits) {
      await notifier.show(alert, instrumentFor(alert.symbol), updated[alert.symbol]!);
    }
  }
}
