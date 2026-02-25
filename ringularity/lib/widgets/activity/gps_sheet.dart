import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/big_button.dart';

/// A standard bottom sheet prompting the user to enable or disable background GPS tracking.
///
/// This sheet is typically presented in the [ActivitySelectionScreen] right before
/// a user starts a new workout session. It can be configured as a strict reminder
/// (only a positive button) or a choice dialogue (positive and negative buttons).
class GpsSheet extends StatelessWidget {
  /// Callback executed when the user agrees or acknowledges the prompt.
  final VoidCallback onPositivePressed;

  /// Callback executed when the user declines the prompt. If null, the negative button is hidden.
  final VoidCallback? onNegativePressed;

  final String title;
  final String message;
  final String positiveLabel;

  /// Creates a new [GpsSheet] instance.
  const GpsSheet({
    super.key,
    required this.onPositivePressed,
    this.onNegativePressed,
    this.title = "GPS Tracking",
    this.message = "Do you want to use GPS from your phone for this session?",
    this.positiveLabel = "Yes",
  });

  @override
  Widget build(BuildContext context) {
    final bool isReminderOnly = onNegativePressed == null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
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
          const SizedBox(height: 30),
          Text(title, style: AppTextStyles.subsubtitle),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodygrey,
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              if (!isReminderOnly) ...[
                Expanded(
                  child: TextButton(
                    onPressed: onNegativePressed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: const Text("No", style: AppTextStyles.bodywhite),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: BigButton(
                  backgroundColor: AppColors.mainColor,
                  onPressed: onPositivePressed,
                  child: Text(
                    positiveLabel,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: Colors.black,
                    ),
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
