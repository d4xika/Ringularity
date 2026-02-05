import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/selection_button.dart';
import '../common/big_button.dart';
import '../../theme/text_styles.dart';

class AddEditGoalDialog extends StatefulWidget {
  final String? initialActivity;
  final String? initialValue;
  final String? initialUnit;

  const AddEditGoalDialog({
    super.key,
    this.initialActivity,
    this.initialValue,
    this.initialUnit,
  });

  @override
  State<AddEditGoalDialog> createState() => _AddEditGoalDialogState();
}

class _AddEditGoalDialogState extends State<AddEditGoalDialog> {
  String? selectedActivity;
  String selectedUnit = "minutes";
  late TextEditingController _valueController;

  final List<String> activities = ["Steps", "Walk", "Running", "Individual"];
  final List<String> units = ["minutes", "hours", "individual"];

  @override
  void initState() {
    super.initState();

    selectedActivity = widget.initialActivity;

    selectedUnit = widget.initialUnit ?? "minutes";

    _valueController = TextEditingController(text: widget.initialValue ?? "");
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Edit Modus
    final bool isEditMode = widget.initialActivity != null;

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditMode ? "Edit Goal" : "Add Goal",
                    style: AppTextStyles.subtitle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.mainColor),
                    onPressed: () {
                      Navigator.pop(context);
                    },
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
                  return SelectionButton(
                    label: activity,
                    isSelected: selectedActivity == activity,
                    onTap: () {
                      setState(() {
                        selectedActivity = activity;
                      });
                    },
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
                        hintStyle: TextStyle(color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
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
                        items: units.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Save / Update Button ---
              BigButton(
                child: Text(
                  isEditMode ? "Update" : "Save",
                  style: AppTextStyles.buttonLabel,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
