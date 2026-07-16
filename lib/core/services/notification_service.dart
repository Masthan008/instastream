import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'download_progress';
  static const String _channelName = 'Download Progress';
  static const String _channelDesc = 'Shows download progress for active downloads';

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String message,
    required int progress,
    bool indeterminate = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: !indeterminate,
      maxProgress: 100,
      progress: progress.clamp(0, 100),
      ongoing: progress < 100,
      autoCancel: progress >= 100,
    );
    await _plugin.show(
      id,
      title,
      message,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String filePath,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      onlyAlertOnce: true,
      showProgress: false,
      autoCancel: true,
    );
    await _plugin.show(
      id,
      'Download Complete',
      title,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
