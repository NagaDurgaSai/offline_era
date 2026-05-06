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
    const settings = InitializationSettings(android: android, macOS: darwin);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showMessage(String sender, String preview) async {
    const android = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'Incoming messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, macOS: darwin);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      sender,
      preview,
      details,
    );
  }

  static Future<void> showFile(String sender, String fileName) async {
    const android = AndroidNotificationDetails(
      'files',
      'Files',
      channelDescription: 'Incoming files',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, macOS: darwin);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      sender,
      'sent you a file: $fileName',
      details,
    );
  }
}
