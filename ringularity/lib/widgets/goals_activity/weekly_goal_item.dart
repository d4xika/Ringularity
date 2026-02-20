import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_model.dart';
import '../../models/weekly_goal_model.dart';
import '../../services/activity_service.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../services/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import 'add_edit_goal_sheet.dart';

class WeeklyGoalItem extends StatelessWidget {
  final WeeklyGoal goal;

  const WeeklyGoalItem({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      ActivityService,
      DailySummaryService,
      BleService,
      VitalsStorageService
    >(
      builder:
          (
            context,
            activityService,
            summaryService,
            bleService,
            vitalsService,
            child,
          ) {
            final double currentProgress = _calculateProgress(
              activityService,
              summaryService,
              bleService,
              vitalsService,
            );

            // Ensure progress doesn't exceed 1.0 for the bar, but value can be higher
            final double progressPercent = (goal.targetValue > 0)
                ? (currentProgress / goal.targetValue).clamp(0.0, 1.0)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal.activityType,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return DraggableScrollableSheet(
                                initialChildSize: 0.65,
                                minChildSize: 0.4,
                                maxChildSize: 0.95,
                                expand: false,
                                builder: (context, scrollController) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(25),
                                      ),
                                    ),
                                    child: AddEditGoalSheet(
                                      scrollController: scrollController,
                                      initialGoal: goal,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 20,
                    child: Stack(
                      children: [
                        // Frame
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.textPrimary,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: progressPercent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.mainColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatValue(currentProgress),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          "/ ${goal.targetValue.toStringAsFixed(0)} ${goal.unit}",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }

  String _formatValue(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0); // No decimals for large numbers (steps)
    }
    // Remove trailing .0 for clean display
    return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  double _calculateProgress(
    ActivityService activityService,
    DailySummaryService summaryService,
    BleService bleService,
    VitalsStorageService vitalsService,
  ) {
    // Use the selected date from BleService to determine the context week
    final selectedDate = bleService.selectedDate;

    // Monday is 1, Sunday is 7
    final startOfWeek = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: selectedDate.weekday - 1));

    if (goal.activityType == "Steps") {
      int totalSteps = 0;

      // Sum history up to today
      // Strategy:
      // 1. Iterate through the week.
      // 2. If the day is the Selected Date, use bleService.steps (matches the Ring).
      // 3. Otherwise, use DailySummaryService.

      for (int i = 0; i < 7; i++) {
        final dateToCheck = startOfWeek.add(Duration(days: i));

        if (DateUtils.isSameDay(dateToCheck, DateTime.now())) {
          // If the day in loop IS Today, use the Real-Time live steps
          // This ensures that even if we are viewing yesterday, today's steps are included
          // in the "This Week" total if today is part of that week.
          totalSteps += bleService.realTimeSteps;
        } else if (DateUtils.isSameDay(dateToCheck, selectedDate)) {
          // If the day is the selected date (and NOT today, caught above),
          // use the steps currently displayed on the dashboard for consistency.
          // (Though technically realTimeSteps and displayed steps might differ for past dates only if history is loaded)
          totalSteps += bleService.steps;
        } else {
          // Other days: Try VitalsStorageService first (more reliable for recent history)
          final vital = vitalsService.getVitalsForDate(dateToCheck);
          if (vital != null && vital.steps > 0) {
            totalSteps += vital.steps;
          } else {
            // Fallback to DailySummaryService
            final summary = summaryService.getSummaryForDate(dateToCheck);
            if (summary != null) {
              totalSteps += summary.steps;
            }
          }
        }
      }

      return totalSteps.toDouble();
    } else {
      // Specific Activity (Run, Walk, etc.)
      double totalValue = 0.0;
      final targetType = _getActivityType(goal.activityType);

      if (targetType != null) {
        for (var activity in activityService.activities) {
          if (_isSameWeek(activity.date, startOfWeek) &&
              activity.type == targetType) {
            // Determine what to sum based on unit
            if (_isTimeUnit(goal.unit)) {
              totalValue += activity.duration.inMinutes;
            } else if (_isDistanceUnit(goal.unit)) {
              totalValue += activity.distanceKm;
            } else {
              if (goal.unit.toLowerCase() == 'steps') {
                totalValue += activity.steps;
              }
            }
          }
        }
      }

      // Handle unit conversions
      if (goal.unit.toLowerCase().contains("hour")) {
        if (_isTimeUnit("minutes")) {
          return totalValue / 60.0;
        }
      }

      return totalValue;
    }
  }

  bool _isSameWeek(DateTime date, DateTime startOfWeek) {
    // Check if date is >= startOfWeek and < startOfWeek + 7 days
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return date.isAtSameMomentAs(startOfWeek) ||
        (date.isAfter(startOfWeek) && date.isBefore(endOfWeek));
  }

  ActivityType? _getActivityType(String typeString) {
    switch (typeString) {
      case "Walk":
        return ActivityType.walk;
      case "Running":
        return ActivityType.run;
      // Add other mappings as needed based on AddEditGoalSheet options
      // ["Steps", "Walk", "Running", "Individual"]
      default:
        return null;
    }
  }

  bool _isTimeUnit(String unit) {
    final u = unit.toLowerCase();
    return u.contains("min") || u.contains("hour") || u.contains("time");
  }

  bool _isDistanceUnit(String unit) {
    final u = unit.toLowerCase();
    return u.contains("km") || u.contains("mile") || u.contains("meter");
  }
}
