import 'package:flutter/material.dart';
import '../common/selection_button.dart'; 

class TimePeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const TimePeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final List<String> _periods = const ["D", "W", "M", "Y"];

  @override
  Widget build(BuildContext context) {
    // Wir entfernen den äußeren Container mit der Decoration,
    // da die SelectionButtons ihre eigene Decoration mitbringen.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _periods.map((p) {
          // Expanded sorgt dafür, dass alle Buttons gleich breit sind
          return Expanded(
            child: Padding(
              // Kleiner Abstand zwischen den Buttons
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