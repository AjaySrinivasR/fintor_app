import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/subscription_model.dart';

class NotificationReminderService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> scheduleBillReminder(Subscription subscription) async {
    final reminderDate =
        subscription.nextBillingDate.subtract(const Duration(days: 2));
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledTz = tz.TZDateTime.from(reminderDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      subscription.id.hashCode,
      'Upcoming Bill Reminder: ${subscription.name}',
      '₹${subscription.amount.toStringAsFixed(0)} due in 2 days on ${subscription.nextBillingDate.day}/${subscription.nextBillingDate.month}.',
      scheduledTz,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fintor_bills',
          'Bill Reminders',
          channelDescription:
              'Notifications for upcoming recurring bills and subscriptions',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(String subscriptionId) async {
    await _notificationsPlugin.cancel(subscriptionId.hashCode);
  }
}
