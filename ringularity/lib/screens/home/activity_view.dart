import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../services/health/activity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/common/custom_scrollbar.dart';
import '../activity/activity_detail_screen.dart';
import '../activity/activity_selection_screen.dart';

/// Displays a chronologically ordered, scrollable list of the user's recorded activities.
///
/// Implements infinite scrolling to load older activities from the backend
/// dynamically as the user scrolls down the list.
class ActivityView extends StatefulWidget {
  /// Creates a new [ActivityView] instance.
  const ActivityView({super.key});

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  /// Tracks how many months into the past the view has currently loaded.
  int _loadedMonthsBack = 1;

  /// Indicates whether there is more historical data available on the backend to fetch.
  bool _hasMore = true;

  /// Prevents overlapping fetch requests while data is currently loading.
  bool _isLoading = false;

  final ScrollController _listScrollController = ScrollController();

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerSync());
  }

  /// Listens to the scroll position and triggers a fetch for older data
  /// when the user scrolls past 80% of the currently loaded list.
  void _scrollListener() {
    if (_listScrollController.position.pixels >=
        _listScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  /// Fetches the next batch of historical activity data from the backend (2 months at a time).
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    _loadedMonthsBack += 2;

    final now = DateTime.now();
    final limitDate = DateTime(now.year, now.month - _loadedMonthsBack, 1);

    final newItemsCount = await Provider.of<ActivityService>(
      context,
      listen: false,
    ).syncFromBackend(limitDate, now);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (newItemsCount == 0) {
          _hasMore = false;
        }
      });
    }
  }

  /// Forces an initial synchronization of the most recent activities upon screen load.
  void _triggerSync() {
    final now = DateTime.now();
    final limitDate = DateTime(now.year, now.month - _loadedMonthsBack, 1);

    Provider.of<ActivityService>(
      context,
      listen: false,
    ).syncFromBackend(limitDate, now);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/starry_night_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Consumer<ActivityService>(
        builder: (context, activityService, child) {
          final now = DateTime.now();
          final limitDate = DateTime(
            now.year,
            now.month - _loadedMonthsBack,
            1,
          );

          final visibleActivities = activityService.activities.where((a) {
            return a.date.isAfter(limitDate) ||
                a.date.isAtSameMomentAs(limitDate);
          }).toList();

          final Map<String, List<ActivityModel>> groupedActivities = {};
          for (var activity in visibleActivities) {
            final String key = DateFormat('MMMM yyyy').format(activity.date);
            if (!groupedActivities.containsKey(key)) {
              groupedActivities[key] = [];
            }
            groupedActivities[key]!.add(activity);
          }

          return SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text("Activities", style: AppTextStyles.title),
                      const SizedBox(height: 20),

                      if (activityService.activities.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              "No activities yet. Start moving!",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: CustomScrollbar(
                            controller: _listScrollController,
                            child: ListView.builder(
                              controller: _listScrollController,
                              padding: const EdgeInsets.only(
                                bottom: 100,
                                right: 20,
                              ),
                              itemCount: groupedActivities.keys.length + 1,
                              itemBuilder: (context, index) {
                                if (index == groupedActivities.keys.length) {
                                  return Opacity(
                                    opacity: _isLoading ? 1.0 : 0.0,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 32.0,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.mainColor,
                                        ),
                                      ),
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
                                        style: AppTextStyles.subsubtitle
                                            .copyWith(
                                              color: AppColors.mainColor,
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ActivitySelectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a clickable tile representing a single recorded activity.
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
                Icon(activity.type.icon, color: AppColors.mainColor),
                const SizedBox(width: 16),
                Text(activity.typeName, style: AppTextStyles.bodywhite),
              ],
            ),
            Text(
              DateFormat('dd.MM.yy').format(activity.date),
              style: AppTextStyles.bodygrey,
            ),
          ],
        ),
      ),
    );
  }
}
