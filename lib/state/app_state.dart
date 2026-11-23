import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/instruments.dart';
import '../models/price_alert.dart';
import '../models/quote.dart';
import '../models/ring_state.dart';
import '../services/alarm_player.dart';
import '../services/alert_engine.dart';
import '../services/alert_notifier.dart';
import '../services/monitor_service.dart';
import '../services/price_service.dart';
import '../services/storage.dart';
import '../services/tone_store.dart';

/// UI-facing state. Reads everything from [AppStorage] and refreshes once a
/// second so changes made by the background service show up immediately.
class AppState extends ChangeNotifier {
  AppState._(this.storage);

  static Future<AppState> create() async {
    final state = AppState._(await AppStorage.open());
    await state._init();
    return state;
  }

  final AppStorage storage;
  final AlarmPlayer alarm = AlarmPlayer();
  final AlertNotifier notifier = AlertNotifier();
  final PriceService prices = PriceService();

  AlertEngine? _foregroundEngine; // iOS only: no background service there
  Timer? _timer;
  String _signature = '';
  bool _ticking = false;
  int _tickCount = 0;

  // ---- Read models -------------------------------------------------------

  List<PriceAlert> get alerts => storage.alerts;
  Map<String, Quote> get quotes => storage.quotes;
  Map<String, int> get fired => storage.fired;
  RingState get ring => storage.ring;
  bool get sleeping => storage.sleeping;
  ThemeMode get themeMode => storage.themeMode;
  int get forexIntervalSec => storage.forexIntervalSec;
  String? get defaultTonePath => storage.defaultTonePath;
  String get apiKey => storage.apiKey;
  String? get feedError => storage.feedError;

  int get activeForexSymbolCount {
    final f = fired;
    return alerts
        .where((a) => a.isActive(f))
        .map((a) => instrumentFor(a.symbol))
        .where((i) => i.source == PriceSource.twelveData)
        .toSet()
        .length;
  }

  // ---- Lifecycle ---------------------------------------------------------

  Future<void> _init() async {
    await notifier.init();
    await storage.setBundledTonePath(await ToneStore.ensureDefault());
    if (Platform.isIOS) {
      _foregroundEngine = AlertEngine(
        storage: storage,
        prices: prices,
        alarm: alarm,
        notifier: notifier,
      );
    }
    await syncMonitor();
    _signature = storage.signature;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onTick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final engine = _foregroundEngine;
      if (engine != null) {
        await engine.tick();
      } else {
        await storage.reload();
      }
      if (++_tickCount % 15 == 0) await syncMonitor();
      _publishIfChanged();
    } finally {
      _ticking = false;
    }
  }

  void _publishIfChanged() {
    final s = storage.signature;
    if (s != _signature) {
      _signature = s;
      notifyListeners();
    }
  }

  /// Starts the Android service only when it has work to do (an armed alert
  /// or a ringing alarm) and the app is not asleep.
  Future<void> syncMonitor() async {
    if (!Platform.isAndroid) return;
    final f = fired;
    final needed = !sleeping && (ring.active || alerts.any((a) => a.isActive(f)));
    if (needed) {
      await MonitorService.ensureRunning();
    } else {
      await MonitorService.stop();
    }
  }

  // ---- Alerts ------------------------------------------------------------

  Future<void> saveAlert(PriceAlert alert) async {
    final list = [...alerts];
    final index = list.indexWhere((a) => a.id == alert.id);
    if (index >= 0) {
      list[index] = alert;
    } else {
      list.add(alert);
    }
    await storage.saveAlerts(list);
    await _afterChange();
  }

  Future<void> deleteAlert(String id) async {
    await storage.saveAlerts(alerts.where((a) => a.id != id).toList());
    await _afterChange();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await storage.saveAlerts([
      for (final a in alerts)
        if (a.id == id) a.copyWith(enabled: enabled, armedAt: enabled ? now : null) else a,
    ]);
    await _afterChange();
  }

  /// Arms a triggered alert again with the same target.
  Future<void> rearm(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await storage.saveAlerts([
      for (final a in alerts) if (a.id == id) a.copyWith(armedAt: now) else a,
    ]);
    await _afterChange();
  }

  Future<void> _afterChange() async {
    await syncMonitor();
    _publishIfChanged();
  }

  // ---- Alarm and sleep ---------------------------------------------------

  Future<void> stopAlarm() async {
    await storage.requestStop();
    // If the background service is gone, nobody else can clear the alarm.
    if (Platform.isAndroid && !await MonitorService.isRunning) {
      await storage.clearRing();
      await notifier.cancelAll();
    }
    _publishIfChanged();
    unawaited(Future<void>.delayed(const Duration(seconds: 2), syncMonitor));
  }

  /// Sleep switches the whole app off: no background service, no network.
  Future<void> setSleeping(bool value) async {
    await storage.setSleeping(value);
    if (value) {
      await storage.requestStop();
      await storage.clearRing();
      await notifier.cancelAll();
      await alarm.stop();
    }
    await _afterChange();
  }

  // ---- Settings ----------------------------------------------------------

  Future<void> setThemeMode(ThemeMode mode) async {
    await storage.setThemeMode(mode);
    _publishIfChanged();
  }

  Future<void> setForexInterval(int seconds) async {
    await storage.setForexIntervalSec(seconds);
    _publishIfChanged();
  }

  Future<void> setApiKey(String key) async {
    await storage.setApiKey(key);
    _publishIfChanged();
  }

  Future<void> setDefaultTone(String? path) async {
    await storage.setDefaultTonePath(path);
    _publishIfChanged();
  }

  Future<String?> pickTone() => ToneStore.pickCustom();

  Future<void> previewTone(String? path) => alarm.preview(path ?? defaultTonePath ?? storage.bundledTonePath);

  /// One-off price lookup used by the alert form.
  Future<double> fetchPrice(Instrument instrument) async {
    if (sleeping) throw PriceException('App is asleep (offline)');
    final result = instrument.source == PriceSource.binance
        ? await prices.fetchBinance([instrument])
        : await prices.fetchTwelveData([instrument], apiKey);
    final price = result[instrument.symbol];
    if (price == null) throw PriceException('No price returned');
    return price;
  }

  // ---- Permissions -------------------------------------------------------

  Future<void> requestInitialPermissions() async {
    if (!await notificationsGranted()) await requestNotifications();
  }

  Future<bool> notificationsGranted() async {
    if (!Platform.isAndroid) return true;
    return await FlutterForegroundTask.checkNotificationPermission() == NotificationPermission.granted;
  }

  Future<void> requestNotifications() async {
    if (Platform.isAndroid) {
      await FlutterForegroundTask.requestNotificationPermission();
    } else {
      await notifier.requestPermissions();
    }
  }

  Future<bool> batteryUnrestricted() async {
    if (!Platform.isAndroid) return true;
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  Future<void> requestBatteryUnrestricted() async {
    if (Platform.isAndroid) await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }
}
