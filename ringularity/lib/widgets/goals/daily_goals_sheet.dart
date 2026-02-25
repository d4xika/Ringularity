import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ble/ble_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../common/big_button.dart';

/// A bottom sheet dialogue allowing users to adjust their baseline daily macro-goals.
///
/// Affects the thresholds used to calculate completion percentages for the
/// Activity Rings (Steps, Sleep, Activity Minutes) on the dashboard.
class DailyGoalsSheet extends StatefulWidget {
  final String currentSteps;
  final String currentSleep;
  final String currentActivity;
  final ScrollController? scrollController;

  /// Creates a new [DailyGoalsSheet] instance.
  const DailyGoalsSheet({
    super.key,
    this.currentSteps = "5000",
    this.currentSleep = "8",
    this.currentActivity = "25",
    this.scrollController,
  });

  @override
  State<DailyGoalsSheet> createState() => _DailyGoalsSheetState();
}

class _DailyGoalsSheetState extends State<DailyGoalsSheet> {
  late TextEditingController _stepsController;
  late TextEditingController _sleepController;
  late TextEditingController _activityController;

  @override
  void initState() {
    super.initState();
    _stepsController = TextEditingController(text: widget.currentSteps);
    _sleepController = TextEditingController(text: widget.currentSleep);
    _activityController = TextEditingController(text: widget.currentActivity);
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _activityController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          controller: widget.scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text("Daily Goals", style: AppTextStyles.subtitle),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.mainColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                _buildInputRow(_stepsController, "steps"),
                const SizedBox(height: 20),
                _buildInputRow(_sleepController, "h sleep"),
                const SizedBox(height: 20),
                _buildInputRow(_activityController, "min activity"),

                const SizedBox(height: 40),

                BigButton(
                  backgroundColor: AppColors.mainColor,
                  onPressed: () {
                    final service = context.read<BleService>();
                    final int? steps = int.tryParse(_stepsController.text);
                    final double? sleep = double.tryParse(
                      _sleepController.text,
                    );
                    final int? activity = int.tryParse(
                      _activityController.text,
                    );

                    if (steps != null && sleep != null && activity != null) {
                      service.updateGoals(steps, sleep, activity);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Update",
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a formatted row containing a numeric text input field and its corresponding unit suffix.
  Widget _buildInputRow(TextEditingController controller, String suffix) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            cursorColor: Colors.white,
            style: AppTextStyles.subsubtitle,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.mainColor, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            suffix,
            textAlign: TextAlign.left,
            style: AppTextStyles.subsubtitle,
          ),
        ),
      ],
    );
  }
}
