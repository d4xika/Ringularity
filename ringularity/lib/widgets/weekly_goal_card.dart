import 'package:flutter/material.dart';
import 'package:ringularity/widgets/add_edit_goal_dialog.dart';
import '../theme/app_colors.dart';

class WeeklyGoalCard extends StatelessWidget {
  const WeeklyGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Text(
                "Running",
                style: TextStyle(
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
                  // Edit Modus
                  showDialog(
                    context: context,
                    builder: (context) => const AddEditGoalDialog(
                      initialActivity: "Running", 
                      initialValue: "3",          
                      initialUnit: "hours",       
                    ),
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
                // Füllung
                FractionallySizedBox(
                  widthFactor: 0.45,
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

          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "3h 4min",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Text(
                  "/ 7h",
                  style: TextStyle(
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