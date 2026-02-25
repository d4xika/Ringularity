import 'package:flutter/material.dart';

import '../../theme/text_styles.dart';

/// The large, prominent numeric display appearing at the top of the History screen.
///
/// Automatically switches its subtitle between "TOTAL" and "AVERAGE" depending on
/// whether the user is viewing cumulative metrics (like Steps) or continuous metrics (like HR).
class StatSummaryHeader extends StatelessWidget {
  /// Defines the semantic prefix ("TOTAL" vs "AVERAGE").
  final bool isTotal;

  /// The primary large number string to display.
  final String value;

  /// The suffix appended to the value (e.g. "bpm").
  final String unit;

  /// The color of the numeric value, often turning white during chart scrubbing.
  final Color valueColor;

  /// An optional string, typically used to display a specific time when scrubbing.
  final String? subValue;

  /// Callback triggered when the calendar icon is tapped.
  final VoidCallback onCalendarTap;

  /// Creates a new [StatSummaryHeader] instance.
  const StatSummaryHeader({
    super.key,
    required this.isTotal,
    required this.value,
    this.subValue,
    required this.unit,
    required this.valueColor,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTotal ? "TOTAL" : "AVERAGE",
                style: AppTextStyles.bodygrey.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: valueColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unit.isNotEmpty)
                        Text(unit, style: AppTextStyles.bodygrey),
                    ],
                  ),
                  SizedBox(
                    height: 24,
                    child: subValue != null
                        ? Text(subValue!, style: AppTextStyles.bodywhite)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: IconButton(
              onPressed: onCalendarTap,
              icon: const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
