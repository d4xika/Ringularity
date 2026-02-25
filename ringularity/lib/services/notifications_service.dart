import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:ringularity/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orchestrates all OS-level Push Notifications.
///
/// Manages permissions, channels (Android 8.0+ requirement), and the scheduling
/// of both immediate alerts (e.g. low battery) and recurring reminders (e.g. daily sync).
class NotificationService {
  static Future<bool> _isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Callback fired when the user taps on a notification banner outside the app.
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint("Notification clicked! App is opening.");
  }

  /// Bootstraps the AwesomeNotifications plugin and registers required OS channels.
  static Future<void> initializeNotification() async {
    await AwesomeNotifications()
        .initialize('resource://drawable/ic_notification', [
          NotificationChannel(
            channelKey: 'sync_channel',
            channelName: 'Sync Reminder',
            channelDescription: 'Reminder to sync your data',
            defaultColor: AppColors.cardBackground,
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            onlyAlertOnce: true,
            criticalAlerts: true,
          ),
          NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic Notifications',
            channelDescription:
                'Standard notifications for goals and achievements',
            defaultColor: AppColors.mainColor,
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
          ),
        ], debug: true);

    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }

    if (isAllowed) {
      await updateAllSchedules();
    }
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }

  /// Clears and recreates all time-based recurring notifications based on user preferences.
  static Future<void> updateAllSchedules() async {
    final enabled = await _isEnabled();

    await AwesomeNotifications().cancelAllSchedules();

    if (!enabled) return;

    await _scheduleDailySync();
  }

  /// Creates a daily recurring reminder at 17:00 to prompt the user to open the app and sync.
  static Future<void> _scheduleDailySync() async {
    if (!await _isEnabled()) return;
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'sync_channel',
        title: 'Time to sync!',
        body: "Don't forget to sync your data for today!",
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: 17,
        minute: 00,
        second: 0,
        millisecond: 0,
        repeats: true,
      ),
    );
  }

  /// Fires an immediate critical alert if the ring's battery drops to 30% or lower.
  static Future<void> showBatteryWarning(int batteryLevel) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 2,
        channelKey: 'basic_channel',
        title: 'Low Battery! 🔋',
        body: 'Your ring only has $batteryLevel%. Please Charge!',
        notificationLayout: NotificationLayout.Default,
        payload: {'type': 'battery_alert'},
      ),
    );
  }

  /// Fires an alert if the sync detects that the user slept for less than 6 hours.
  static Future<void> showSleepWarning(int minutes) async {
    final hours = (minutes / 60).floor();
    final remainingMinutes = minutes % 60;
    final timeString = "${hours}h ${remainingMinutes}min";

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 3,
        channelKey: 'basic_channel',
        title: 'Slept badly? 😴',
        body:
            'Today you only slept for $timeString. Try to rest a little today!',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
        payload: {'type': 'sleep_alert'},
      ),
    );
  }

  /// Fires a congratulatory alert when the user successfully finishes an Activity session.
  static Future<void> showActivityCelebration() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 4,
        channelKey: 'basic_channel',
        title: 'Exercise completed! 🏃‍♂️',
        body: 'Great job! You completed an activity!',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Event,
        payload: {'type': 'activity_summary'},
      ),
    );
  }

  /// Fires a mindfulness suggestion if the user's daily stress average exceeds 50.
  static Future<void> showStressWarning(int stressLevel) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 5,
        channelKey: 'basic_channel',
        title: 'Time for a break? 🧘',
        body:
            'Your average stress level is currently at $stressLevel. Take a moment for a short breathing exercise.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
        payload: {'type': 'stress_alert'},
      ),
    );
  }

  /// Clears all active notifications from the OS drawer and resets the app icon badge counter to 0.
  static Future<void> resetNotifications() async {
    await AwesomeNotifications().getGlobalBadgeCounter().then((value) {
      if (value > 0) {
        AwesomeNotifications().setGlobalBadgeCounter(0);
      }
    });
    await AwesomeNotifications().dismissAllNotifications();
  }
}
