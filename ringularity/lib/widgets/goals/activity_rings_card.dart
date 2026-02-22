import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/health/vitals_storage_service.dart';

import '../../services/daily_summary_service.dart';
import '../../services/health/activity_service.dart';
import '../../theme/app_colors.dart';
import '../common/date_selector.dart';
import 'daily_goals_sheet.dart';

class ActivityRingsCard extends StatefulWidget {
  const ActivityRingsCard({super.key});

  @override
  State<ActivityRingsCard> createState() => _ActivityRingsCardState();
}

class _ActivityRingsCardState extends State<ActivityRingsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<VitalsStorageService>(context);

    return Consumer3<BleService, ActivityService, DailySummaryService>(
      builder: (context, bleService, activityService, summaryService, child) {
        final selectedDate = bleService.selectedDate;
        final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

        int currentSteps = 0;
        double currentSleepHours = 0.0;
        int currentActivity = 0;
        String displaySleep = "0h 0min";

        int goalSteps = bleService.goalSteps;
        double goalSleepHours = bleService.goalSleep;
        int goalActivityMinutes = bleService.goalActivity;

        for (var activity in activityService.activities) {
          if (DateUtils.isSameDay(activity.date, selectedDate)) {
            currentActivity += activity.duration.inMinutes;
          }
        }

        if (isToday) {
          currentSteps = bleService.steps;
          currentSleepHours = bleService.totalSleepMinutes / 60.0;
          displaySleep = bleService.totalSleepTimeFormatted;
        } else {
          final historicalVitals = storageService.getVitalsForDate(
            selectedDate,
          );
          if (historicalVitals != null) {
            currentSteps = historicalVitals.steps;
          }

          final sleepData = bleService.getSleepDataForDate(selectedDate);
          int totalSleepMins = 0;
          for (var s in sleepData) {
            if (s.stage != 0x05) {
              totalSleepMins += s.durationMinutes;
            }
          }
          currentSleepHours = totalSleepMins / 60.0;

          final hours = currentSleepHours.floor();
          final mins = ((currentSleepHours - hours) * 60).round();
          displaySleep = "${hours}h ${mins}min";

          final summary = summaryService.getSummaryForDate(selectedDate);
          if (summary != null) {
            goalSteps = summary.goalSteps > 0 ? summary.goalSteps : goalSteps;
            goalSleepHours = summary.goalSleep > 0
                ? summary.goalSleep
                : goalSleepHours;
            goalActivityMinutes = summary.goalActivity > 0
                ? summary.goalActivity
                : goalActivityMinutes;
          }
        }

        final double percentSteps = goalSteps > 0
            ? (currentSteps / goalSteps).clamp(0.0, 1.0)
            : 0.0;
        final double percentSleep = goalSleepHours > 0
            ? (currentSleepHours / goalSleepHours).clamp(0.0, 1.0)
            : 0.0;
        final double percentActivity = goalActivityMinutes > 0
            ? (currentActivity / goalActivityMinutes).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    DateSelector(
                      selectedDate: bleService.selectedDate,
                      onPrevious: () {
                        final newDate = bleService.selectedDate.subtract(
                          const Duration(days: 1),
                        );
                        bleService.setSelectedDate(newDate);
                      },
                      onNext: () {
                        final newDate = bleService.selectedDate.add(
                          const Duration(days: 1),
                        );
                        bleService.setSelectedDate(newDate);
                      },
                      canGoNext: !isToday,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _RingsPainter(
                              percentSteps: percentSteps * _animation.value,
                              percentSleep: percentSleep * _animation.value,
                              percentActivity:
                                  percentActivity * _animation.value,
                            ),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _RingLabel(
                              label: "Steps",
                              value: "$currentSteps",
                              subText: "/$goalSteps steps",
                              color: AppColors.accentBlue,
                            ),
                            _RingLabel(
                              label: "Sleep",
                              value: displaySleep,
                              subText: "/${goalSleepHours.toInt()} h",
                              color: AppColors.accentCyan,
                            ),
                            _RingLabel(
                              label: "Activity",
                              value: "${currentActivity}min",
                              subText: "/$goalActivityMinutes min",
                              color: AppColors.accentGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 15,
                right: 15,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) {
                        return DraggableScrollableSheet(
                          initialChildSize: 0.55,
                          minChildSize: 0.4,
                          maxChildSize: 0.85,
                          expand: false,
                          builder: (context, scrollController) {
                            return DailyGoalsSheet(
                              scrollController: scrollController,
                              currentSteps: "$goalSteps",
                              currentSleep: "$goalSleepHours",
                              currentActivity: "$goalActivityMinutes",
                            );
                          },
                        );
                      },
                    );
                  },
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.white70.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingLabel extends StatelessWidget {
  final String label;
  final String value;
  final String subText;
  final Color color;

  const _RingLabel({
    required this.label,
    required this.value,
    required this.subText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(subText, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double percentSteps;
  final double percentSleep;
  final double percentActivity;

  _RingsPainter({
    required this.percentSteps,
    required this.percentSleep,
    required this.percentActivity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 12.0;
    const double spacing = 6.0;

    final center = Offset(size.width / 2, size.height);
    final double baseRadius = min(size.width / 2.2, size.height * 0.9);

    _drawArc(
      canvas,
      center,
      baseRadius,
      AppColors.accentBlue,
      percentSteps,
      strokeWidth,
    );

    _drawArc(
      canvas,
      center,
      baseRadius - strokeWidth - spacing,
      AppColors.accentCyan,
      percentSleep,
      strokeWidth,
    );

    _drawArc(
      canvas,
      center,
      baseRadius - (2 * (strokeWidth + spacing)),
      AppColors.accentGreen,
      percentActivity,
      strokeWidth,
    );
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double percent,
    double strokeWidth,
  ) {
    final paintBg = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final paintFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, pi, pi, false, paintBg);

    canvas.drawArc(rect, pi, pi * percent, false, paintFg);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.percentSteps != percentSteps ||
        oldDelegate.percentSleep != percentSleep ||
        oldDelegate.percentActivity != percentActivity;
  }
}
