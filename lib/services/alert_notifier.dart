import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/instruments.dart';
import '../models/price_alert.dart';

/// Shows the full-screen "alert fired" notification. The sound itself comes
/// from [AlarmPlayer], so the notification is silent.
class AlertNotifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'forex_alert_triggered';

  Future<void> init() async {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_alert'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Price alerts',
          description: 'Shown when a price target is reached',
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
        ));
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> show(PriceAlert alert, Instrument instrument, double price) {
    final body = StringBuffer('Reached ${instrument.format(price)} '
        '(target ${instrument.format(alert.target)})');
    if (alert.note.isNotEmpty) body.write(' · ${alert.note}');

    return _plugin.show(
      alert.id.hashCode & 0x7fffffff,
      'Price alert: ${alert.symbol}',
      body.toString(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Price alerts',
          channelDescription: 'Shown when a price target is reached',
          icon: 'ic_stat_alert',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
