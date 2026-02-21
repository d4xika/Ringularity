import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/weekly_goal_model.dart';
import '../../services/health/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../common/big_button.dart';

class AddEditGoalSheet extends StatefulWidget {
  final WeeklyGoal? initialGoal;
  final ScrollController scrollController;

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
  String selectedUnit = "minutes";
  late TextEditingController _valueController;
  late TextEditingController _customActivityController;
  late TextEditingController _customUnitController;

  late FocusNode _customActivityFocusNode;
  late FocusNode _customUnitFocusNode;

  final List<String> activities = ["Steps", "Walk", "Running", "Individual"];
  final List<String> units = ["steps", "minutes", "hours", "individual"];

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
    _customActivityController = TextEditingController();
    _customUnitController = TextEditingController();

    _customActivityFocusNode = FocusNode();
    _customUnitFocusNode = FocusNode();

    if (widget.initialGoal != null) {
      final goal = widget.initialGoal!;
      _valueController.text = goal.targetValue.toStringAsFixed(
        0,
      ); // Assuming integer for now from UI perspective

      // Determine activity
      if (activities.contains(goal.activityType) &&
          goal.activityType != "Individual") {
        selectedActivity = goal.activityType;
      } else {
        selectedActivity = "Individual";
        _customActivityController.text = goal.activityType;
      }

      // Determine unit
      if (units.contains(goal.unit) && goal.unit != "individual") {
        selectedUnit = goal.unit;
      } else {
        selectedUnit = "individual";
        _customUnitController.text = goal.unit;
      }

      // Sanity check: If activity is NOT Steps, unit cannot be steps.
      // This handles legacy data or invalid states.
      if (selectedActivity != "Steps" && selectedUnit == "steps") {
        selectedUnit = "minutes";
      }
    } else {
      // Default new goal state
      selectedUnit = "minutes";
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _customActivityController.dispose();
    _customUnitController.dispose();
    _customActivityFocusNode.dispose();
    _customUnitFocusNode.dispose();
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
                final bool isIndividual = activity == "Individual";

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedActivity = activity;

                      if (selectedActivity == "Steps") {
                        selectedUnit = "steps";
                      } else if (selectedUnit == "steps") {
                        // If switching away from Steps, reset unit to default if it was steps
                        selectedUnit = "minutes";
                      }
                    });
                    if (isIndividual) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _customActivityFocusNode.requestFocus();
                      });
                    }
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
                      child: (isIndividual && isSelected)
                          ? TextField(
                              controller: _customActivityController,
                              focusNode: _customActivityFocusNode,
                              style: const TextStyle(
                                color: AppColors.mainColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              cursorColor: AppColors.mainColor,
                              decoration: const InputDecoration(
                                hintText: "Name...",
                                hintStyle: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            )
                          : Text(
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
                      : selectedUnit == "individual"
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _customUnitController,
                                focusNode: _customUnitFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                cursorColor: AppColors.mainColor,
                                decoration: const InputDecoration(
                                  hintText: "Unit...",
                                  hintStyle: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedUnit = "minutes";
                                  _customUnitController.clear();
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                          ],
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
                                .where(
                                  (u) => u != "steps",
                                ) // Hide "steps" from dropdown for other activities
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
                final finalActivity = (selectedActivity == "Individual")
                    ? _customActivityController.text.trim()
                    : selectedActivity;

                final finalUnit = (finalActivity == "Steps")
                    ? "steps"
                    : (selectedUnit == "individual")
                    ? _customUnitController.text.trim()
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
                  // Update existing goal
                  final updatedGoal = widget.initialGoal!.copyWith(
                    activityType: finalActivity,
                    targetValue: finalValue,
                    unit: finalUnit,
                  );
                  goalService.updateWeeklyGoal(updatedGoal);
                } else {
                  // Add new goal
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
