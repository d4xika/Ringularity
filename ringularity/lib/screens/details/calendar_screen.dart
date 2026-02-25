import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../services/health/activity_service.dart';
import '../../services/health/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/goals/mini_activity_rings.dart';

/// A full-screen calendar view displaying historical goal completion.
///
/// Implements a deeply scrollable vertical list of months. Each day cell dynamically
/// loads and displays a miniature activity ring representing the user's progress
/// (steps, sleep, activity) for that specific date.
class CalendarScreen extends StatefulWidget {
  /// Creates a new [CalendarScreen] instance.
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// The absolute starting boundary of the calendar (e.g., 1 year ago).
  final DateTime _startDate = DateTime(
    DateTime.now().year - 1,
    DateTime.now().month,
    1,
  );

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  late DateTime _currentHeaderDate;

  @override
  void initState() {
    super.initState();
    _currentHeaderDate = DateTime.now();

    _itemPositionsListener.itemPositions.addListener(_onVisibleItemsChanged);

    // Automatically jump to the current month upon entering the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final monthIndex =
          (now.year - _startDate.year) * 12 + (now.month - _startDate.month);

      if (monthIndex >= 0 && monthIndex < 36) {
        _itemScrollController.jumpTo(index: monthIndex);
      }
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onVisibleItemsChanged);
    super.dispose();
  }

  /// Calculates which month is currently visible at the top of the viewport
  /// to update the sticky header accordingly.
  void _onVisibleItemsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;

    if (positions.isEmpty) return;

    final sortedPositions = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final topItem = sortedPositions.first;
    final index = topItem.index;

    final newDate = DateTime(_startDate.year, _startDate.month + index);

    if (newDate.month != _currentHeaderDate.month ||
        newDate.year != _currentHeaderDate.year) {
      setState(() {
        _currentHeaderDate = newDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ScreenHeader(
                title:
                    "${_getMonthName(_currentHeaderDate.month)} ${_currentHeaderDate.year}",
              ),
            ),

            _buildWeekDaysHeader(),

            Expanded(
              child: ScrollablePositionedList.builder(
                itemCount: 36, // 3 Years total range
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                itemBuilder: (context, index) {
                  final monthDate = DateTime(
                    _startDate.year,
                    _startDate.month + index,
                  );
                  return _buildMonthItem(monthDate);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the static header showing the days of the week (Mon-Sun).
  Widget _buildWeekDaysHeader() {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map(
              (day) => SizedBox(
                width: 40,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodygrey.copyWith(fontSize: 14),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Builds the container and title for a single month within the scrollable list.
  Widget _buildMonthItem(DateTime monthDate) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 24.0,
        left: 10,
        right: 10,
        top: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
            child: Text(
              _getMonthAbbreviation(monthDate.month),
              style: AppTextStyles.subsubtitle,
            ),
          ),
          _buildMonthGrid(monthDate),
        ],
      ),
    );
  }

  /// Builds the actual 7-column grid of days for a given month.
  ///
  /// Pulls data from multiple services ([DailySummaryService], [ActivityService],
  /// [VitalsStorageService], [BleService]) to calculate and draw the activity rings for each day.
  Widget _buildMonthGrid(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;

    return Consumer4<
      DailySummaryService,
      ActivityService,
      VitalsStorageService,
      BleService
    >(
      builder:
          (
            context,
            summaryService,
            activityService,
            storageService,
            bleService,
            child,
          ) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 4,
              ),
              itemCount: daysInMonth + (firstWeekday - 1),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1)
                  return const SizedBox(); // Empty padding for correct weekday offset

                final day = index - (firstWeekday - 1) + 1;
                final dateKey = DateTime(monthDate.year, monthDate.month, day);
                final isToday = DateUtils.isSameDay(dateKey, DateTime.now());

                double stepsPercent = 0.0;
                double sleepPercent = 0.0;
                double activityPercent = 0.0;
                bool hasData = false;

                int daySteps = 0;
                double daySleep = 0.0;
                int dayActivity = 0;

                int gSteps = bleService.goalSteps;
                double gSleep = bleService.goalSleep;
                int gActivity = bleService.goalActivity;

                // 1. Gather Activity Data
                for (var act in activityService.activities) {
                  if (DateUtils.isSameDay(act.date, dateKey)) {
                    dayActivity += act.duration.inMinutes;
                    hasData = true;
                  }
                }

                // 2. Gather Vitals Data (Live vs Historical)
                if (isToday) {
                  daySteps = bleService.steps;
                  daySleep = bleService.totalSleepMinutes / 60.0;
                  if (daySteps > 0 || daySleep > 0) hasData = true;
                } else {
                  final historicalVitals = storageService.getVitalsForDate(
                    dateKey,
                  );
                  if (historicalVitals != null) {
                    daySteps = historicalVitals.steps;
                    hasData = true;
                  }

                  final sleepData = bleService.getSleepDataForDate(dateKey);
                  if (sleepData.isNotEmpty) {
                    int totalSleepMins = 0;
                    for (var s in sleepData) {
                      if (s.stage != 0x05) totalSleepMins += s.durationMinutes;
                    }
                    daySleep = totalSleepMins / 60.0;
                    hasData = true;
                  }
                }

                // 3. Gather Goals and calculate percentages
                final summary = summaryService.getSummaryForDate(dateKey);
                if (summary != null) {
                  gSteps = summary.goalSteps > 0 ? summary.goalSteps : gSteps;
                  gSleep = summary.goalSleep > 0 ? summary.goalSleep : gSleep;
                  gActivity = summary.goalActivity > 0
                      ? summary.goalActivity
                      : gActivity;
                }

                if (gSteps > 0)
                  stepsPercent = (daySteps / gSteps).clamp(0.0, 1.0);
                if (gSleep > 0)
                  sleepPercent = (daySleep / gSleep).clamp(0.0, 1.0);
                if (gActivity > 0)
                  activityPercent = (dayActivity / gActivity).clamp(0.0, 1.0);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);

                    if (dateKey.isAfter(today)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You cannot see into the future!"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Return the selected date to the parent screen
                    Navigator.pop(context, dateKey);
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (hasData)
                              MiniActivityRings(
                                size: 38,
                                stepsPercent: stepsPercent,
                                sleepPercent: sleepPercent,
                                activityPercent: activityPercent,
                              )
                            else
                              Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$day",
                        style: AppTextStyles.bodygrey.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            );
          },
    );
  }

  /// Helper returning the full english string for a month index.
  String _getMonthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return months[month - 1];
  }

  /// Helper returning the 3-letter english string for a month index.
  String _getMonthAbbreviation(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
  }
}
