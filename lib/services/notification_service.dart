import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // =========================
  // INIT
  // =========================
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // ANDROID CHANNEL
    const androidChannel = AndroidNotificationChannel(
      'subscription_reminders',
      'Subscription Reminders',
      description: 'Reminders for upcoming subscriptions',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  // =========================
  // REQUEST PERMISSION (ANDROID 13+)
  // =========================
  static Future<void> requestPermission() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // =========================
  // SCHEDULE NOTIFICATION
  // =========================
  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_reminders',
          'Subscription Reminders',
          channelDescription: 'Reminders for upcoming subscriptions',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),

      // ✅ IMPORTANT: INEXACT (NO SYSTEM BLOCK)
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
  }

  // =========================
  // CANCEL
  // =========================
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
