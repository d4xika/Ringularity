import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/big_button.dart';
import '../../theme/text_styles.dart';

class AddEditGoalSheet extends StatefulWidget {
  final String? initialActivity;
  final String? initialValue;
  final String? initialUnit;
  final ScrollController scrollController;

  const AddEditGoalSheet({
    super.key,
    this.initialActivity,
    this.initialValue,
    this.initialUnit,
    required this.scrollController,
  });

  @override
  State<AddEditGoalSheet> createState() => _AddEditGoalSheetState();
}

class _AddEditGoalSheetState extends State<AddEditGoalSheet> {
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
    final bool isEditMode = widget.initialActivity != null;

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
                final bool isSelected = selectedActivity == activity;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedActivity = activity;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
                          color: isSelected ? AppColors.mainColor : Colors.white,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
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

            BigButton(
              backgroundColor: AppColors.mainColor,
              child: Text(
                isEditMode ? "Update" : "Save",
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.black)
                  , 
              ),
              onPressed: () {
                //TODO: Speichern der Daten 
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}