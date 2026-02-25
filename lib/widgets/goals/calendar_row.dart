import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/health/vitals_storage_service.dart';

import '../../services/daily_summary_service.dart';
import '../../services/health/activity_service.dart';
import '../../theme/text_styles.dart';
import 'mini_activity_rings.dart';

/// A horizontal quick-navigation bar displaying the 7 days of the currently selected week.
///
/// Generates miniature, static activity rings for each day to provide a rapid visual
/// overview of the week's overall fitness progress. Tapping a day alters the global `selectedDate`.
class CalendarRow extends StatelessWidget {
  /// The anchor date determining which specific Monday-to-Sunday week is displayed.
  final DateTime selectedDate;

  /// Creates a new [CalendarRow] instance.
  const CalendarRow({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final int daysSinceMonday = selectedDate.weekday - DateTime.monday;
    final DateTime startOfWeek = selectedDate.subtract(
      Duration(days: daysSinceMonday),
    );

    final List<DateTime> weekDates = List.generate(7, (index) {
      return startOfWeek.add(Duration(days: index));
    });

    final storageService = Provider.of<VitalsStorageService>(context);

    return Consumer3<DailySummaryService, ActivityService, BleService>(
      builder: (context, summaryService, activityService, bleService, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekDates.map((date) {
            final isToday = DateUtils.isSameDay(date, DateTime.now());

            double stepsPercent = 0.0;
            double sleepPercent = 0.0;
            double activityPercent = 0.0;

            int daySteps = 0;
            double daySleep = 0.0;
            int dayActivity = 0;

            int gSteps = bleService.goalSteps;
            double gSleep = bleService.goalSleep;
            int gActivity = bleService.goalActivity;

            for (var act in activityService.activities) {
              if (DateUtils.isSameDay(act.date, date)) {
                dayActivity += act.duration.inMinutes;
              }
            }

            if (isToday) {
              daySteps = bleService.steps;
              daySleep = bleService.totalSleepMinutes / 60.0;
            } else {
              final historicalVitals = storageService.getVitalsForDate(date);
              if (historicalVitals != null) {
                daySteps = historicalVitals.steps;
              }

              final sleepData = bleService.getSleepDataForDate(date);
              int totalSleepMins = 0;
              for (var s in sleepData) {
                if (s.stage != 0x05) totalSleepMins += s.durationMinutes;
              }
              daySleep = totalSleepMins / 60.0;
            }

            final summary = summaryService.getSummaryForDate(date);
            if (summary != null) {
              gSteps = summary.goalSteps > 0 ? summary.goalSteps : gSteps;
              gSleep = summary.goalSleep > 0 ? summary.goalSleep : gSleep;
              gActivity = summary.goalActivity > 0
                  ? summary.goalActivity
                  : gActivity;
            }

            if (gSteps > 0) stepsPercent = (daySteps / gSteps).clamp(0.0, 1.0);
            if (gSleep > 0) sleepPercent = (daySleep / gSleep).clamp(0.0, 1.0);
            if (gActivity > 0)
              activityPercent = (dayActivity / gActivity).clamp(0.0, 1.0);

            return _buildDayItem(
              date,
              stepsPercent,
              sleepPercent,
              activityPercent,
              bleService,
            );
          }).toList(),
        );
      },
    );
  }

  /// Constructs the individual clickable day icon.
  Widget _buildDayItem(
    DateTime date,
    double steps,
    double sleep,
    double activity,
    BleService bleService,
  ) {
    final String dayName = DateFormat('E').format(date);
    final bool isSelected = DateUtils.isSameDay(date, selectedDate);
    final bool isFuture = date.isAfter(DateTime.now());

    return GestureDetector(
      onTap: isFuture ? null : () => bleService.setSelectedDate(date),
      child: Opacity(
        opacity: isFuture ? 0.3 : 1.0,
        child: Column(
          children: [
            Text(
              dayName,
              style: AppTextStyles.bodywhite.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: Colors.white24, width: 1)
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: MiniActivityRings(
                size: 28,
                stepsPercent: steps,
                sleepPercent: sleep,
                activityPercent: activity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
