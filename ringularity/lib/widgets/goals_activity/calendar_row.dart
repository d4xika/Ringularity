import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

    return Consumer2<DailySummaryService, ActivityService>(
      builder: (context, summaryService, activityService, child) {
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
  ) {
    final String dayName = DateFormat('E').format(date);

    return Column(
      children: [
        Text(dayName, style: AppTextStyles.bodywhite),
        const SizedBox(height: 8),
        MiniActivityRings(
          size: 28,
          stepsPercent: steps,
          sleepPercent: sleep,
          activityPercent: activity,
        ),
      ],
    );
  }
}
