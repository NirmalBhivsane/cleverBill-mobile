import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/api.dart';

/// FCM + local notifications. Foreground messages are shown with sound via a
/// high-importance channel so alerts (low stock, dues) are audible.
class PushService {
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'cleverbill_alerts',
    'Clever Bill alerts',
    description: 'Bills, payments and stock alerts',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init() async {
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _local.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      });
    } catch (_) {
      /* push is optional */
    }
  }

  static Future<void> register(Api api) async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await api.registerDeviceToken(t);
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (t) => api.registerDeviceToken(t),
      );
    } catch (_) {}
  }
}
