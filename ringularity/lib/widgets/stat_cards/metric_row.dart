import 'package:flutter/material.dart';

import '../../theme/text_styles.dart';

/// A simple, horizontal layout summarizing a specific data point.
///
/// Typically used within stat cards to cleanly present a label
/// alongside its corresponding value and a contextual icon.
class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Creates a new [MetricRow] instance.
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        const SizedBox(width: 16),
        Text(label, style: AppTextStyles.bodygrey),
        const Spacer(),
        Text(value, style: AppTextStyles.subsubtitle),
      ],
    );
  }
}
