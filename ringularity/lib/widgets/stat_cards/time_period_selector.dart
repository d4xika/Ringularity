import 'package:flutter/material.dart';

import '../common/selection_button.dart';

/// A segmented control bar allowing the user to filter charts by Time (Day, Week, Month, Year).
class TimePeriodSelector extends StatelessWidget {
  /// The currently active filter string ("D", "W", "M", "Y").
  final String selectedPeriod;

  /// Callback fired when the user selects a different timeframe.
  final Function(String) onPeriodChanged;

  /// Creates a new [TimePeriodSelector] instance.
  const TimePeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final List<String> _periods = const ["D", "W", "M", "Y"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _periods.map((p) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: SelectionButton(
                label: p,
                isSelected: selectedPeriod == p,
                onTap: () => onPeriodChanged(p),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
