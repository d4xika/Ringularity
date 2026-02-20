import 'dart:math';

import 'package:flutter/widgets.dart';

class ChartViewModel {
  final List<Point> points;
  final Widget labels;
  final double minY;
  final double maxY;
  final DateTime startTime;
  final int durationMinutes;
  final int labelIntervalMinutes;
  final bool isTrend;
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
