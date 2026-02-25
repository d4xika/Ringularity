import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A subtle, circular widget displaying the ring's current battery level.
///
/// Incorporates a progressive drawing animation on load and automatically
/// turns red when the battery drops below a critical threshold (30%).
class BatteryIndicator extends StatefulWidget {
  /// The battery fill level as a decimal between 0.0 (empty) and 1.0 (full).
  final double percentage;

  /// Dictates the active styling. If false, the indicator grays out and displays a disconnect icon.
  final bool isConnected;

  /// Callback triggered when the indicator is tapped.
  final VoidCallback? onTap;

  /// Creates a new [BatteryIndicator] instance.
  const BatteryIndicator({
    super.key,
    required this.percentage,
    required this.isConnected,
    required this.onTap,
  });

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.percentage,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.isConnected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(BatteryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage ||
        oldWidget.isConnected != widget.isConnected) {
      _animation =
          Tween<double>(
            begin: _animation.value,
            end: widget.isConnected ? widget.percentage : 0,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color getStatusColor() {
      if (!widget.isConnected) return Colors.grey;
      return widget.percentage < 0.3 ? Colors.red : AppColors.accentGreen;
    }

    final statusColor = getStatusColor();

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _BatteryPainter(
              percentage: _animation.value,
              color: statusColor,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                widget.isConnected ? Icons.bolt : Icons.link_off,
                color: statusColor,
                size: 17,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The low-level canvas painter responsible for drawing the battery circle.
class _BatteryPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  _BatteryPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    const strokeWidth = 3.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (percentage <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percentage,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}
