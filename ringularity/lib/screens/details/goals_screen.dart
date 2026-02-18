import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/goals_activity/activity_rings.dart';
import '../../widgets/goals_activity/add_edit_goal_sheet.dart';
import '../../widgets/goals_activity/calendar_row.dart';
import '../../widgets/goals_activity/weekly_goal_item.dart';
import 'calendar_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('d MMM y').format(now);

    return Scaffold(
      extendBody: true,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.mainColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mainColor.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: BigButton(
            child: const Icon(Icons.add, color: AppColors.mainColor, size: 32),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  // Use a StatefulWidget or simply rely on MediaQuery via builder rebuilds.
                  // When keyboard opens, viewInsets.bottom > 0.
                  final double bottomInset = MediaQuery.of(
                    context,
                  ).viewInsets.bottom;
                  final bool isKeyboardOpen =
                      bottomInset >
                      100; // Threshold to ensure it's actually the keyboard

                  return DraggableScrollableSheet(
                    initialChildSize: isKeyboardOpen ? 0.95 : 0.65,
                    minChildSize: isKeyboardOpen ? 0.95 : 0.4,
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
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/starry_night_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  ScreenHeader(
                    title: formattedDate,
                    actionWidget: IconButton(
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalendarScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  const CalendarRow(),

                  const SizedBox(height: 25),

                  Text("Daily Goals", style: AppTextStyles.subtitle),

                  const SizedBox(height: 12),

                  const SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: ActivityRingsCard(),
                  ),

                  const SizedBox(height: 20),

                  Text("Weekly Goals", style: AppTextStyles.subtitle),

                  const SizedBox(height: 12),

                  Consumer<GoalService>(
                    builder: (context, goalService, child) {
                      final goals = goalService.weeklyGoals;
                      if (goals.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Center(
                            child: Text(
                              "No goals set. Add one!",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: goals.length,
                        itemBuilder: (context, index) {
                          return WeeklyGoalItem(goal: goals[index]);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
