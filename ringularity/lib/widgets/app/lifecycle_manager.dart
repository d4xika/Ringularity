import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/health/activity_service.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../services/network_status_service.dart';

class LifecycleManager extends StatefulWidget {
  final Widget child;

  const LifecycleManager({super.key, required this.child});

  @override
  State<LifecycleManager> createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final networkStatus = Provider.of<NetworkStatusService>(
      context,
      listen: false,
    );

    if (state == AppLifecycleState.resumed) {
      // Re-check connectivity immediately and restart the polling timer.
      networkStatus.checkNow();
      networkStatus.startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stop polling while the app is in the background to save battery.
      networkStatus.stopPolling();
      _saveDailyProgress();
    }
  }

  void _saveDailyProgress() {
    final bleService = Provider.of<BleService>(context, listen: false);
    final activityService = Provider.of<ActivityService>(
      context,
      listen: false,
    );
    final summaryService = Provider.of<DailySummaryService>(
      context,
      listen: false,
    );

    final today = DateTime.now();

    int todayActivityMins = 0;
    for (var act in activityService.activities) {
      if (DateUtils.isSameDay(act.date, today)) {
        todayActivityMins += act.duration.inMinutes;
      }
    }

    summaryService.saveOrUpdateDay(
      date: today,
      steps: bleService.steps,
      sleepHours: bleService.totalSleepMinutes / 60.0,
      activityMinutes: todayActivityMins,
      goalSteps: bleService.goalSteps,
      goalSleep: bleService.goalSleep,
      goalActivity: bleService.goalActivity,
    );

    debugPrint(
      "LifecycleManager: Daily data was backed up safely in the background!",
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
