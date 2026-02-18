import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/activity_service.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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
    // Always save for today, using real-time values
    // Using realTimeSteps ensures we capture today's steps even if viewing history
    summaryService.saveOrUpdateDay(
      date: today,
      steps: bleService.realTimeSteps,
      sleepHours:
          bleService.totalSleepMinutes /
          60.0, // Note: Sleep might still be context-dependent, but steps are fixed
      activityMinutes: todayActivityMins,
      goalSteps: bleService.goalSteps,
      goalSleep: bleService.goalSleep,
      goalActivity: bleService.goalActivity,
    );

    debugPrint("LifecycleManager: Daily data was backed up in the background!");
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
