import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../models/weekly_goal_model.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../services/health/activity_service.dart';
import '../../services/health/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import 'add_edit_goal_sheet.dart';

/// A UI component representing a specific, user-defined weekly challenge.
///
/// Features a dynamic progress bar that iterates across the entire current week
/// to compute the cumulative progress toward the goal's target value.
class WeeklyGoalItem extends StatelessWidget {
  final WeeklyGoal goal;

  /// Creates a new [WeeklyGoalItem] instance referencing a specific [goal].
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
                      Text(goal.activityType, style: AppTextStyles.subsubtitle),
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
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.textPrimary,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                        style: AppTextStyles.subsubtitle.copyWith(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          "/ ${goal.targetValue.toStringAsFixed(0)} ${goal.unit}",
                          style: AppTextStyles.bodygrey.copyWith(fontSize: 14),
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

  /// Removes ugly trailing zeros from decimal formats unless the number represents large integer scales.
  String _formatValue(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  /// Algorithm calculating cumulative weekly progress by querying various services based on the goal's target metric.
  double _calculateProgress(
    ActivityService activityService,
    DailySummaryService summaryService,
    BleService bleService,
    VitalsStorageService vitalsService,
  ) {
    final selectedDate = bleService.selectedDate;

    final startOfWeek = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: selectedDate.weekday - 1));

    if (goal.activityType == "Steps") {
      int totalSteps = 0;

      for (int i = 0; i < 7; i++) {
        final dateToCheck = startOfWeek.add(Duration(days: i));

        if (DateUtils.isSameDay(dateToCheck, DateTime.now())) {
          totalSteps += bleService.realTimeSteps;
        } else if (DateUtils.isSameDay(dateToCheck, selectedDate)) {
          totalSteps += bleService.steps;
        } else {
          final vital = vitalsService.getVitalsForDate(dateToCheck);
          if (vital != null && vital.steps > 0) {
            totalSteps += vital.steps;
          } else {
            final summary = summaryService.getSummaryForDate(dateToCheck);
            if (summary != null) {
              totalSteps += summary.steps;
            }
          }
        }
      }

      return totalSteps.toDouble();
    } else {
      double totalValue = 0.0;
      final targetType = _getActivityType(goal.activityType);

      if (targetType != null) {
        for (var activity in activityService.activities) {
          if (_isSameWeek(activity.date, startOfWeek) &&
              activity.type == targetType) {
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

      if (goal.unit.toLowerCase().contains("hour")) {
        if (_isTimeUnit("minutes")) {
          return totalValue / 60.0;
        }
      }

      return totalValue;
    }
  }

  bool _isSameWeek(DateTime date, DateTime startOfWeek) {
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
