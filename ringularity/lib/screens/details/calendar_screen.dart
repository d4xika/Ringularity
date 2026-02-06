import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; 
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/goals_activity/mini_activity_rings.dart';
import '../../theme/text_styles.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Wir starten 1 Jahr in der Vergangenheit
  final DateTime _startDate = DateTime(
    DateTime.now().year - 1,
    DateTime.now().month,
    1,
  );

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  late DateTime _currentHeaderDate;

  // DUMMY DATEN
  final Map<DateTime, List<double>> _demoProgress = {};

  @override
  void initState() {
    super.initState();
    _currentHeaderDate = DateTime.now(); 
    _generateDemoData();

    _itemPositionsListener.itemPositions.addListener(_onVisibleItemsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = DateTime.now();
        final monthIndex = (now.year - _startDate.year) * 12 + (now.month - _startDate.month);
        
        if(monthIndex >= 0 && monthIndex < 36) {
           _itemScrollController.jumpTo(index: monthIndex);
        }
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onVisibleItemsChanged);
    super.dispose();
  }

  void _onVisibleItemsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    
    if (positions.isEmpty) return;
    
    //Items nach Index sortieren, um das oberste zu finden
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

  void _generateDemoData() {
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));

      _demoProgress[date] = [
        (i % 10) / 10.0,
        (i % 5) / 5.0,
        0.8 + (i % 2) * 0.2,
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
              child: ScrollablePositionedList.builder(
                itemCount: 36, // 3 Jahre
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
