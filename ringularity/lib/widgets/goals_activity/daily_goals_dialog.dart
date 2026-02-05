import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../common/big_button.dart';

class DailyGoalsDialog extends StatefulWidget {
  final String currentSteps;
  final String currentSleep;
  final String currentActivity;

  const DailyGoalsDialog({
    super.key,
    this.currentSteps = "5000",
    this.currentSleep = "8",
    this.currentActivity = "25",
  });

  @override
  State<DailyGoalsDialog> createState() => _DailyGoalsDialogState();
}

class _DailyGoalsDialogState extends State<DailyGoalsDialog> {
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
    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Daily Goals", style: AppTextStyles.subtitle),
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
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Update", style: AppTextStyles.buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget um die Zeilen zu bauen (Input + Text)
  Widget _buildInputRow(TextEditingController controller, String suffix) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end, // Damit Text auf Linie sitzt
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
