import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:ringularity/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static Future<bool> _isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  static Future<void> initializeNotification() async {
    await AwesomeNotifications().initialize(null, [
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
    ], debug: true);

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  static Future<void> updateAllSchedules() async {
    final enabled = await _isEnabled();

    await AwesomeNotifications().cancelAllSchedules();

    if (!enabled) return;

    await _scheduleDailySync();
    // Hier später weitere hinzufügen:
  }

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
        minute: 0,
        second: 0,
        millisecond: 0,
        repeats: true,
      ),
    );
  }

  static Future<void> resetNotifications() async {
    await AwesomeNotifications().getGlobalBadgeCounter().then((value) {
      if (value > 0) {
        AwesomeNotifications().setGlobalBadgeCounter(0);
      }
    });
    await AwesomeNotifications().dismissAllNotifications();
  }
}
