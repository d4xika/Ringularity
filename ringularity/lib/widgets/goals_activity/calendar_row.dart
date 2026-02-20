import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';

import '../../services/activity_service.dart';
import '../../services/daily_summary_service.dart';
import '../../theme/text_styles.dart';
import 'mini_activity_rings.dart';

class CalendarRow extends StatelessWidget {
  final DateTime selectedDate;

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

    return Consumer3<DailySummaryService, ActivityService, BleService>(
      builder: (context, summaryService, activityService, bleService, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekDates.map((date) {
            final summary = summaryService.getSummaryForDate(date);

            double stepsPercent = 0.0;
            double sleepPercent = 0.0;
            double activityPercent = 0.0;

            if (summary != null) {
              if (summary.goalSteps > 0) {
                stepsPercent = (summary.steps / summary.goalSteps).clamp(
                  0.0,
                  1.0,
                );
              }
              if (summary.goalSleep > 0) {
                sleepPercent = (summary.sleepHours / summary.goalSleep).clamp(
                  0.0,
                  1.0,
                );
              }
            }

            int dailyActivityMins = 0;
            for (var act in activityService.activities) {
              if (DateUtils.isSameDay(act.date, date)) {
                dailyActivityMins += act.duration.inMinutes;
              }
            }

            final goalActivity = summary?.goalActivity ?? 30;
            if (goalActivity > 0) {
              activityPercent = (dailyActivityMins / goalActivity).clamp(
                0.0,
                1.0,
              );
            }

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
