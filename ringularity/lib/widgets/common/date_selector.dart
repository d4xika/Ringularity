import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
