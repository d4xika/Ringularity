import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import 'activity_detail_screen.dart';
import 'activity_selection_screen.dart';

class ActivityView extends StatefulWidget {
  const ActivityView({super.key});

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  final List<ActivityModel> _allActivities = [
    ActivityModel(
      type: ActivityType.walk,
      date: DateTime.now().subtract(const Duration(days: 1)),
      duration: const Duration(minutes: 55),
      distanceKm: 1.02,
      avgHeartRate: 153,
    ),
    ActivityModel(
      type: ActivityType.run,
      date: DateTime.now().subtract(const Duration(days: 5)),
      duration: const Duration(minutes: 30),
      distanceKm: 5.0,
      avgHeartRate: 160,
    ),
    ActivityModel(
      type: ActivityType.cycling,
      date: DateTime(2025, 9, 23),
      duration: const Duration(minutes: 45),
      distanceKm: 12.0,
      avgHeartRate: 140,
    ),
    ActivityModel(
      type: ActivityType.walk,
      date: DateTime(2025, 9, 10),
      duration: const Duration(minutes: 20),
      distanceKm: 1.5,
      avgHeartRate: 110,
    ),
    ActivityModel(
      type: ActivityType.hiking,
      date: DateTime(2025, 8, 15),
      duration: const Duration(hours: 2),
      distanceKm: 8.0,
      avgHeartRate: 130,
    ),
    ActivityModel(
      type: ActivityType.run,
      date: DateTime(2025, 7, 20),
      duration: const Duration(minutes: 40),
      distanceKm: 6.0,
      avgHeartRate: 165,
    ),
  ];

  int _loadedMonthsBack = 1;
  List<ActivityModel> get _visibleActivities {
    final now = DateTime.now();
    final limitDate = DateTime(now.year, now.month - _loadedMonthsBack, 1);

    return _allActivities
        .where(
          (a) =>
              a.date.isAfter(limitDate) || a.date.isAtSameMomentAs(limitDate),
        )
        .toList();
  }

  void _loadMore() {
    setState(() {
      _loadedMonthsBack += 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<ActivityModel>> groupedActivities = {};
    for (var activity in _visibleActivities) {
      final String key = DateFormat('MMMM yyyy').format(activity.date);
      if (!groupedActivities.containsKey(key)) {
        groupedActivities[key] = [];
      }
      groupedActivities[key]!.add(activity);
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/starry_night_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Activities",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: groupedActivities.keys.length + 1,
                      itemBuilder: (context, index) {
                        if (index == groupedActivities.keys.length) {
                          return TextButton(
                            onPressed: _loadMore,
                            child: const Text(
                              "Load more",
                              style: TextStyle(color: AppColors.mainColor),
                            ),
                          );
                        }

                        final String monthKey = groupedActivities.keys
                            .elementAt(index);
                        final List<ActivityModel> monthActivities =
                            groupedActivities[monthKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Text(
                                monthKey,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: AppColors.mainColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...monthActivities.map(
                              (activity) =>
                                  _buildActivityTile(context, activity),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: BigButton(
                backgroundColor: AppColors.mainColor,
                child: Text(
                  "Start Activity",
                  style: AppTextStyles.buttonLabel.copyWith(
                    color: Colors.black,
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivitySelectionScreen(),
                    ),
                  );

                  if (result != null && result is ActivityModel) {
                    setState(() {
                      _allActivities.insert(0, result);
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, ActivityModel activity) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailScreen(activity: activity),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(activity.type),
                  color: AppColors.mainColor,
                ),
                const SizedBox(width: 16),
                Text(
                  activity.typeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              DateFormat('dd.MM.yy').format(activity.date),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(ActivityType type) {
    switch (type) {
      case ActivityType.walk:
        return Icons.directions_walk;
      case ActivityType.run:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.hiking:
        return Icons.landscape;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.gym:
        return Icons.fitness_center;
      case ActivityType.yoga:
        return Icons.self_improvement;
      case ActivityType.dance:
        return Icons.music_note;
      case ActivityType.pilates:
        return Icons.accessibility_new;
      case ActivityType.individual:
        return Icons.edit_note;
      default:
        return Icons.fitness_center;
    }
  }
}
