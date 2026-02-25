import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/weekly_goal_model.dart';
import '../../services/health/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../common/big_button.dart';

/// A bottom sheet dialogue allowing users to define or mutate a custom [WeeklyGoal].
///
/// Permits selection of an activity type (e.g. Walk, Run), a numeric target,
/// and a contextual measurement unit (e.g. min, steps). Validates input to prevent
/// nonsensical combinations (e.g., "Run 5000 Steps" is invalid, but "Walk 30 min" is valid).
class AddEditGoalSheet extends StatefulWidget {
  /// If provided, pre-fills the form to edit an existing goal. If null, creates a new one.
  final WeeklyGoal? initialGoal;

  final ScrollController scrollController;

  /// Creates a new [AddEditGoalSheet] instance.
  const AddEditGoalSheet({
    super.key,
    this.initialGoal,
    required this.scrollController,
  });

  @override
  State<AddEditGoalSheet> createState() => _AddEditGoalSheetState();
}

class _AddEditGoalSheetState extends State<AddEditGoalSheet> {
  String? selectedActivity;
  String selectedUnit = "min";
  late TextEditingController _valueController;

  final List<String> activities = ["Steps", "Walk", "Running"];
  final List<String> units = ["steps", "min", "h"];

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();

    if (widget.initialGoal != null) {
      final goal = widget.initialGoal!;
      _valueController.text = goal.targetValue.toStringAsFixed(0);

      if (activities.contains(goal.activityType)) {
        selectedActivity = goal.activityType;
      } else {
        selectedActivity = "Walk";
      }

      if (units.contains(goal.unit)) {
        selectedUnit = goal.unit;
      } else {
        selectedUnit = "min";
      }

      if (selectedActivity != "Steps" && selectedUnit == "steps") {
        selectedUnit = "min";
      }
    } else {
      selectedUnit = "min";
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.initialGoal != null;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditMode ? "Edit Goal" : "Add Goal",
                  style: AppTextStyles.subtitle,
                ),
                Row(
                  children: [
                    if (isEditMode)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          final goalService = context.read<GoalService>();
                          goalService.removeWeeklyGoal(widget.initialGoal!.id);
                          Navigator.pop(context);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.mainColor),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Activity", style: AppTextStyles.subsubtitle),

            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                final bool isSelected = selectedActivity == activity;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedActivity = activity;

                      if (selectedActivity == "Steps") {
                        selectedUnit = "steps";
                      } else if (selectedUnit == "steps") {
                        selectedUnit = "min";
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.mainColor.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.mainColor
                            : Colors.white10,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        activity,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.mainColor
                              : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            const Text("Value", style: AppTextStyles.subsubtitle),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    cursorColor: Colors.white,
                    style: AppTextStyles.subsubtitle,
                    decoration: const InputDecoration(
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.mainColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: selectedActivity == "Steps"
                      ? Center(
                          child: Text(
                            "steps",
                            style: AppTextStyles.bodywhite.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUnit,
                            dropdownColor: AppColors.cardBackground,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                            style: AppTextStyles.bodywhite,
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedUnit = newValue!;
                              });
                            },
                            items: units
                                .where((u) => u != "steps")
                                .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  color: AppColors.mainColor,
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodywhite.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
            BigButton(
              backgroundColor: AppColors.mainColor,
              onPressed: () {
                final finalActivity = selectedActivity;

                final finalUnit = (finalActivity == "Steps")
                    ? "steps"
                    : selectedUnit;

                final String valueStr = _valueController.text.trim();

                if (finalActivity == null || finalActivity.isEmpty) {
                  setState(() {
                    _errorMessage = "Please select or enter an activity!";
                  });
                  return;
                }
                if (valueStr.isEmpty) {
                  setState(() {
                    _errorMessage = "Please enter a value!";
                  });
                  return;
                }

                if (finalUnit.isEmpty) {
                  setState(() {
                    _errorMessage = "Please enter a custom unit!";
                  });
                  return;
                }

                final double? finalValue = double.tryParse(valueStr);

                if (finalValue == null) {
                  setState(() {
                    _errorMessage = "Please enter a valid number!";
                  });
                  return;
                }

                setState(() {
                  _errorMessage = null;
                });

                final goalService = context.read<GoalService>();

                if (isEditMode) {
                  final updatedGoal = widget.initialGoal!.copyWith(
                    activityType: finalActivity,
                    targetValue: finalValue,
                    unit: finalUnit,
                  );
                  goalService.updateWeeklyGoal(updatedGoal);
                } else {
                  final newGoal = WeeklyGoal(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    activityType: finalActivity,
                    targetValue: finalValue,
                    unit: finalUnit,
                  );
                  goalService.addWeeklyGoal(newGoal);
                }

                Navigator.pop(context);
              },
              child: Text(
                isEditMode ? "Update" : "Save",
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
