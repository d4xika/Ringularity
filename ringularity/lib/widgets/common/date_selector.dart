import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/text_styles.dart';

/// A horizontal navigator widget allowing the user to step backwards or forwards through days.
class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// If false, grays out the forward chevron (preventing navigation into the future).
  final bool canGoNext;

  /// Creates a new [DateSelector] instance.
  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    this.canGoNext = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('EEE, d MMM').format(selectedDate),
          style: AppTextStyles.subsubtitle,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: Icon(
            Icons.chevron_right,
            color: canGoNext ? Colors.white : Colors.white24,
            size: 28,
          ),
        ),
      ],
    );
  }
}
