import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
    await _plugin.initialize(settings);
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> showMessage(
    String sender,
    String preview, {
    String? tag,
    int? id,
  }) async {
    final notifId = id ?? (tag?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final android = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'Incoming messages',
      importance: Importance.high,
      priority: Priority.high,
      tag: tag,
      // Keep per-peer overwrite via `id`/`tag`; avoid Android group quirks.
      groupKey: null,
    );
    const darwin = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, macOS: darwin);
    await _plugin.show(notifId, sender, preview, details);
  }

  static Future<void> showFile(String sender, String fileName, {String? tag}) async {
    final notifId = tag?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final android = AndroidNotificationDetails(
      'files',
      'Files',
      channelDescription: 'Incoming files',
      importance: Importance.high,
      priority: Priority.high,
      tag: tag,
      groupKey: null,
    );
    const darwin = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, macOS: darwin);
    await _plugin.show(notifId, sender, 'sent you: $fileName', details);
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
