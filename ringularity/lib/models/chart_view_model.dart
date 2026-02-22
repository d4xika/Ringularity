import 'dart:math';

import 'package:flutter/widgets.dart';

/// Holds all pre-calculated data and configuration required to render a dynamic chart.
class ChartViewModel {
  /// The normalized coordinates to be drawn.
  final List<Point> points;

  /// The pre-built X-axis label widget.
  final Widget labels;

  final double minY;
  final double maxY;
  final DateTime startTime;
  final int durationMinutes;
  final int labelIntervalMinutes;

  /// Indicates if the chart represents a wider time trend (e.g. week, month, year) rather than a single day.
  final bool isTrend;

  /// The calculated average to be drawn as a reference line.
  final double? averageY;

  final double? minX;
  final double? maxX;

  ChartViewModel(
    this.points,
    this.labels,
    this.minY,
    this.maxY,
    this.startTime,
    this.durationMinutes,
    this.labelIntervalMinutes, {
    this.isTrend = false,
    this.averageY,
    this.minX,
    this.maxX,
  });
}
