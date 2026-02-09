import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/ble/ble_constants.dart';
import '../../../models/sleep_data.dart';

class SleepGraph extends StatefulWidget {
  final List<SleepData> data;

  const SleepGraph({Key? key, required this.data}) : super(key: key);

  @override
  State<SleepGraph> createState() => _SleepGraphState();
}

class _SleepGraphState extends State<SleepGraph> {
  SleepData? _selectedBlock;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: Text("No sleep data for this day")),
      );
    }

    // Sort data just in case
    final sortedData = List<SleepData>.from(widget.data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate dynamic start and end times
    // Start time: First block timestamp
    // End time: Last block timestamp + duration
    final startTime = sortedData.first.timestamp;
    final lastBlock = sortedData.last;
    final endTime = lastBlock.timestamp.add(Duration(
        minutes:
            lastBlock.durationMinutes > 0 ? lastBlock.durationMinutes : 15));

    // Add padding (e.g. 15 mins before and after)
    final displayStart = startTime.subtract(const Duration(minutes: 30));
    final displayEnd = endTime.add(const Duration(minutes: 30));
    final totalDuration = displayEnd.difference(displayStart);

    return Container(
      height: 300, // Increased height for better visibility
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Sleep Stages",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_selectedBlock != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    "${DateFormat('HH:mm').format(_selectedBlock!.timestamp)} - ${_getStageName(_selectedBlock!.stage)} (${_selectedBlock!.durationMinutes} min)",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanUpdate: (details) => _handleTouch(
                      details.localPosition,
                      constraints.maxWidth,
                      displayStart,
                      totalDuration,
                      sortedData),
                  onTapDown: (details) => _handleTouch(
                      details.localPosition,
                      constraints.maxWidth,
                      displayStart,
                      totalDuration,
                      sortedData),
                  onPanEnd: (_) => setState(() => _selectedBlock = null),
                  // onTapUp: (_) => setState(() => _selectedBlock = null), // Optional: keep selected on tap?
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _SleepGraphPainter(
                      data: sortedData,
                      startTime: displayStart,
                      totalDuration: totalDuration,
                      selectedBlock: _selectedBlock,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.orange[300]!, "Awake"),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.blue[200]!, "Light"),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.indigo, "Deep"),
            ],
          ),
          const SizedBox(height: 8),
          // Start/End Time Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('HH:mm').format(startTime),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(DateFormat('HH:mm').format(endTime),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  void _handleTouch(Offset localPosition, double width, DateTime startTime,
      Duration totalDuration, List<SleepData> data) {
    // Convert X position to Time
    final pct = localPosition.dx / width;
    final timeOffsetMinutes = totalDuration.inMinutes * pct;
    final touchedTime =
        startTime.add(Duration(minutes: timeOffsetMinutes.toInt()));

    // Find block containing this time
    SleepData? hit;
    for (var block in data) {
      final blockStart = block.timestamp;
      final blockEnd = blockStart.add(Duration(minutes: block.durationMinutes));
      if (touchedTime.isAfter(blockStart) && touchedTime.isBefore(blockEnd)) {
        hit = block;
        break;
      }
    }

    // Also check for "nearest" if we are close (optional, but good for touch)
    if (hit == null && data.isNotEmpty) {
      // Simple fallback: find closest start time
      // hit = data.reduce((a, b) =>
      //   (a.timestamp.difference(touchedTime).abs() < b.timestamp.difference(touchedTime).abs()) ? a : b);
    }

    if (hit != _selectedBlock) {
      setState(() {
        _selectedBlock = hit;
      });
    }
  }

  String _getStageName(int stage) {
    switch (stage) {
      case BleConstants.sleepAwake:
        return "Awake";
      case BleConstants.sleepLight:
        return "Light";
      case BleConstants.sleepDeep:
        return "Deep";
      default:
        return "Unknown";
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SleepGraphPainter extends CustomPainter {
  final List<SleepData> data;
  final DateTime startTime;
  final Duration totalDuration;
  final SleepData? selectedBlock;

  _SleepGraphPainter({
    required this.data,
    required this.startTime,
    required this.totalDuration,
    this.selectedBlock,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Define Y-levels for Hypnogram style
    // Awake (Top), Light (Middle), Deep (Bottom)
    final yAwake = size.height * 0.1;
    final yLight = size.height * 0.5;
    final yDeep = size.height * 0.9;

    // Draw Axis Lines
    final axisPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, yAwake), Offset(size.width, yAwake), axisPaint);
    canvas.drawLine(Offset(0, yLight), Offset(size.width, yLight), axisPaint);
    canvas.drawLine(Offset(0, yDeep), Offset(size.width, yDeep), axisPaint);

    double totalMinutes = totalDuration.inMinutes.toDouble();
    if (totalMinutes <= 0) totalMinutes = 1;

    // We can also draw lines connecting the blocks to make it a continuous graph
    // But blocks are discrete in the data model given.
    // Let's draw formatted Rect blocks.

    for (int i = 0; i < data.length; i++) {
      final block = data[i];

      // Calculate X
      final durationFromStart = block.timestamp.difference(startTime).inMinutes;
      final xStart = (durationFromStart / totalMinutes) * size.width;

      final blockDuration =
          block.durationMinutes > 0 ? block.durationMinutes : 15;
      final width = (blockDuration / totalMinutes) * size.width;

      Color color;

      switch (block.stage) {
        case BleConstants.sleepAwake:
          color = Colors.orange[300]!;
          break;
        case BleConstants.sleepLight:
          color = Colors.blue[200]!;
          break;
        case BleConstants.sleepDeep:
          color = Colors.indigo;
          break;
        default:
          color = Colors.grey;
      }

      // Highlight if selected
      if (selectedBlock == block) {
        paint.color = color; // Full opacity
        // Draw a selection border or indicator
        canvas.drawRect(
            Rect.fromLTWH(xStart, 0, width, size.height),
            Paint()
              ..color = Colors.black.withOpacity(0.05)
              ..style = PaintingStyle.fill);
      } else {
        paint.color = color.withOpacity(0.85);
      }

      // Draw Block
      // Hypnogram style: usually a line, but here we can draw a "bar" from bottom or floating rect
      // Let's do floating rect centered on the Y-level for that stage?
      // Or columns?
      // The previous implementation was columns. Let's stick to columns but with varying height to indicate depth visually?
      // Or a classic Hypnogram line?
      // Let's try "Inverted Bar" style which is common:
      // Top is 0. Awake is small bar from top? No, usually:
      // Deep is tall bar, Light is medium, Awake is short.

      double barBottom = size.height;

      if (block.stage == BleConstants.sleepAwake) {
        barBottom = size.height * 0.3;
      } else if (block.stage == BleConstants.sleepLight) {
        barBottom = size.height * 0.6;
      } else {
        barBottom = size.height; // Deep
      }

      // Draw Rect
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(xStart, 0, width, barBottom), paint);

      // If it's the selected block, draw a distinct border
      if (selectedBlock == block) {
        canvas.drawRect(
            Rect.fromLTWH(xStart, 0, width, barBottom),
            Paint()
              ..color = Colors.white.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }

    // Draw current selection line
    if (selectedBlock != null) {
      final durationFromStart =
          selectedBlock!.timestamp.difference(startTime).inMinutes;
      final xStart = (durationFromStart / totalMinutes) * size.width;
      final blockDuration = selectedBlock!.durationMinutes > 0
          ? selectedBlock!.durationMinutes
          : 15;
      final width = (blockDuration / totalMinutes) * size.width;

      final linePaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(xStart + width / 2, 0),
          Offset(xStart + width / 2, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepGraphPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.selectedBlock != selectedBlock ||
        oldDelegate.startTime != startTime;
  }
}
