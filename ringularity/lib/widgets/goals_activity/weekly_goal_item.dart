import 'package:flutter/material.dart';
import '../../models/weekly_goal_model.dart';
import '../../theme/app_colors.dart';
import 'add_edit_goal_sheet.dart';

class WeeklyGoalItem extends StatelessWidget {
  final WeeklyGoal goal;

  const WeeklyGoalItem({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                // Rahmen
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textPrimary, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Füllung - Placeholder progress for now
                FractionallySizedBox(
                  widthFactor: 0.0, // TODO: Calculate progress
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
              const Text(
                "0", // TODO: Real progress
                style: TextStyle(
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
  }
}
