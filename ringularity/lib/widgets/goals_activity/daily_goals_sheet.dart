import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/goal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../common/big_button.dart';

class DailyGoalsSheet extends StatefulWidget {
  final String currentSteps;
  final String currentSleep;
  final String currentActivity;
  final ScrollController? scrollController;

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
    // 1. Hier wickeln wir alles in einen Container mit dem Design
    // 1. Hier wickeln wir alles in einen Container mit dem Design
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors
              .cardBackground, // Hier ist die Farbe jetzt fest definiert
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
                    final int? steps = int.tryParse(_stepsController.text);
                    final double? sleep = double.tryParse(
                      _sleepController.text,
                    );
                    final int? activity = int.tryParse(
                      _activityController.text,
                    );

                    context.read<GoalService>().updateGoals(
                      steps: steps,
                      sleep: sleep,
                      activity: activity,
                    );

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
