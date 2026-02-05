import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/goals_activity/mini_activity_rings.dart';
import '../../widgets/common/custom_scrollbar.dart';
import '../../theme/text_styles.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DateTime _startDate = DateTime(
    DateTime.now().year - 1,
    DateTime.now().month,
    1,
  );
  late ScrollController _scrollController;
  late DateTime _currentHeaderDate;

  // damit der Header weiß, welcher Monat oben ist - ein Monat ist ca. 310 Pixel hoch
  final double _estimatedMonthHeight = 375.0;

  // DUMMY DATEN: Format: "Tag": [Steps%, Activity%, Sleep%]
  final Map<DateTime, List<double>> _demoProgress = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentHeaderDate = DateTime.now();

    _generateDemoData();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wir springen zu "Heute" (ca. Index 12)
      if (_scrollController.hasClients) {
        final now = DateTime.now();
        final monthDiff =
            (now.year - _startDate.year) * 12 + (now.month - _startDate.month);
        // Springe zur geschätzten Position
        _scrollController.jumpTo(monthDiff * _estimatedMonthHeight);
        _onScroll();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;

    // Berechnet anhand der Pixel-Höhe, welcher Monat oben ist
    int index = (offset / _estimatedMonthHeight).floor();
    if (index < 0) index = 0;

    final newDate = DateTime(_startDate.year, _startDate.month + index);

    if (newDate.month != _currentHeaderDate.month ||
        newDate.year != _currentHeaderDate.year) {
      setState(() {
        _currentHeaderDate = newDate;
      });
    }
  }

  void _generateDemoData() {
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));

      // Beispielhafte Prozentwerte generieren
      _demoProgress[date] = [
        (i % 10) / 10.0, // Steps: 0.0 bis 0.9
        (i % 5) / 5.0, // Activity
        0.8 + (i % 2) * 0.2, // Sleep: zwischen 0.8 und 1.0
      ];
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
              child: CustomScrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: 36,
                  itemBuilder: (context, index) {
                    final monthDate = DateTime(
                      _startDate.year,
                      _startDate.month + index,
                    );
                    return _buildMonthItem(monthDate);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

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

  Widget _buildMonthGrid(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;

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
        if (index < firstWeekday - 1) return const SizedBox();

        final day = index - (firstWeekday - 1) + 1;
        final dateKey = DateTime(monthDate.year, monthDate.month, day);

        final progress = _demoProgress[dateKey];

        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress != null)
                    MiniActivityRings(
                      size: 38,
                      stepsPercent: progress[0],
                      activityPercent: progress[1],
                      sleepPercent: progress[2],
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
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        );
      },
    );
  }

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
