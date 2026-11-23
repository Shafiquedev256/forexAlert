import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'alert_engine.dart';

/// Entry point of the Android background isolate.
@pragma('vm:entry-point')
void monitorCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(_MonitorTaskHandler());
}

class _MonitorTaskHandler extends TaskHandler {
  AlertEngine? _engine;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _engine = await AlertEngine.create();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_engine?.tick());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _engine?.dispose();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') unawaited(_engine?.stopRinging());
  }
}

/// Starts and stops the Android foreground service that keeps alerts alive
/// while the app is closed or the phone is locked.
class MonitorService {
  MonitorService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'forex_alert_monitor',
        channelName: 'Price monitoring',
        channelDescription: 'Keeps your price alerts running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false, // Android 15 blocks this; the app restarts it on open
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> ensureRunning() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 4101,
      notificationTitle: 'Forex Alert is watching prices',
      notificationText: 'Your alerts are armed.',
      notificationButtons: const [NotificationButton(id: 'stop', text: 'Stop alarm')],
      callback: monitorCallback,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
