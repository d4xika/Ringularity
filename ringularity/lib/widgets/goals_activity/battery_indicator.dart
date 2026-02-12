import 'package:flutter/material.dart';
import 'dart:math';
import '../../theme/app_colors.dart';

class BatteryIndicator extends StatefulWidget {
  final double percentage;
  final bool isConnected;

  const BatteryIndicator({
    super.key,
    required this.percentage,
    required this.isConnected,
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

    return AnimatedBuilder(
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
    );
  }
}

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
