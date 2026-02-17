import 'package:flutter/material.dart';

class StatSummaryHeader extends StatelessWidget {
  final bool isTotal;
  final String value;
  final String unit;
  final Color valueColor;
  final String? subValue;
  final VoidCallback onCalendarTap;

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
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTotal ? "TOTAL" : "AVERAGE",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
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
                        Text(
                          unit,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                  // Reserve space for subValue (Time) to prevent jump
                  SizedBox(
                    height: 24, // Fixed height for subtitle
                    child: subValue != null
                        ? Text(
                            subValue!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          )
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
