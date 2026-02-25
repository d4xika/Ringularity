import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ringularity/theme/text_styles.dart';

import '../../theme/app_colors.dart';

/// A highly interactive, customizable line or bar chart.
///
/// Features a unique "scrubbing" interaction: users can drag their finger horizontally
/// across the chart to snap to specific data points. A custom overlay indicates the exact
/// X and Y values at the finger's position.
class ScrubbableChart extends StatefulWidget {
  /// The raw X/Y coordinate pairs to be plotted.
  final List<Point> dataPoints;

  /// A pre-built row of text widgets forming the X-axis labels.
  final Widget chartLabels;

  final double minY;
  final double maxY;

  /// If true, draws smooth bezier curves between points instead of sharp, straight lines.
  final bool isCurved;

  /// If true, renders a small circular dot at every explicit data point.
  final bool showDots;

  /// Indicates if this chart represents a long-term aggregated trend (Week, Month, Year) rather than a single day.
  final bool isTrend;

  /// Optional limit for the horizontal slider (normalized 0.0 to 1.0).
  /// If provided, the user cannot drag the interaction line past this percentage of the chart's width.
  final double? limitX;

  /// Callback executed continuously while the user drags across the chart.
  /// Provides the interpolated [value] (Y), the raw [x] coordinate, and the normalized [progress] (0.0 to 1.0).
  /// Yields `null` when the user lifts their finger.
  final void Function(double? value, double? x, double? progress)?
  onValueSelected;

  /// An optional average value to be drawn as a dashed horizontal reference line.
  final double? averageY;

  /// If true, visually dims non-selected bars when the user is actively scrubbing a specific bar.
  final bool highlightScrubbedBar;

  /// If true, renders the data as vertical bars (histograms) instead of a continuous line.
  final bool useBars;

  /// A callback allowing individual bars to be colored dynamically based on their Y-value.
  final Color Function(double value)? barColorBuilder;

  final double? minX;
  final double? maxX;

  /// Creates a new [ScrubbableChart] instance.
  const ScrubbableChart({
    super.key,
    required this.dataPoints,
    required this.chartLabels,
    required this.minY,
    required this.maxY,
    this.limitX,
    this.onValueSelected,
    this.averageY,
    this.highlightScrubbedBar = true,
    this.isCurved = true,
    this.showDots = false,
    this.useBars = false,
    this.barColorBuilder,
    this.minX,
    this.maxX,
    this.isTrend = false,
  });

  @override
  State<ScrubbableChart> createState() => _ScrubbableChartState();
}

class _ScrubbableChartState extends State<ScrubbableChart> {
  double _sliderPosition = 0.5;

  final double yAxisWidth = 40.0;
  final double chartPaddingLeft = 10.0;
  final double chartPaddingRight = 20.0;
  final double chartPaddingBottom = 30.0;

  @override
  void initState() {
    super.initState();
    if (widget.limitX != null && _sliderPosition > widget.limitX!) {
      _sliderPosition = widget.limitX!;
    }
  }

  @override
  void didUpdateWidget(covariant ScrubbableChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.limitX != null && _sliderPosition > widget.limitX!) {
      _sliderPosition = widget.limitX!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        final double chartDrawWidth =
            availableWidth - yAxisWidth - chartPaddingLeft - chartPaddingRight;

        final double sliderXInChart = _sliderPosition * chartDrawWidth;

        final double knobAbsoluteX =
            chartPaddingLeft + yAxisWidth + sliderXInChart;

        void updatePosition(double localX) {
          final double startX = chartPaddingLeft + yAxisWidth;
          final double relativeX = localX - startX;
          double newPos = relativeX / chartDrawWidth;

          if (newPos < 0.0) newPos = 0.0;
          if (newPos > 1.0) newPos = 1.0;

          if (widget.limitX != null && newPos > widget.limitX!) {
            newPos = widget.limitX!;
          }

          setState(() {
            _sliderPosition = newPos;
            _reportValue(chartDrawWidth);
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            updatePosition(details.localPosition.dx);
          },
          onHorizontalDragUpdate: (details) {
            updatePosition(details.localPosition.dx);
          },
          onHorizontalDragEnd: (details) {
            widget.onValueSelected?.call(null, null, null);
          },
          onTapDown: (details) {
            updatePosition(details.localPosition.dx);
          },
          onTapUp: (details) {
            widget.onValueSelected?.call(null, null, null);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChartBackgroundPainter(
                    color: AppColors.cardBackground,
                    knobX: knobAbsoluteX,
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  chartPaddingLeft,
                  20,
                  chartPaddingRight,
                  45,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: yAxisWidth,
                            child: LayoutBuilder(
                              builder: (context, boxConstraints) {
                                return Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      child: _buildYLabel(widget.maxY),
                                    ),
                                    if (boxConstraints.maxHeight > 45)
                                      Positioned(
                                        top: (boxConstraints.maxHeight / 2) - 7,
                                        child: _buildYLabel(
                                          (widget.minY + widget.maxY) / 2,
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      child: _buildYLabel(widget.minY),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          Expanded(
                            child: CustomPaint(
                              painter: _LineChartPainter(
                                dataPoints: widget.dataPoints,
                                maxY: widget.maxY,
                                minY: widget.minY,
                                isTrend: widget.isTrend,
                                averageY: widget.averageY,
                                highlightScrubbedBar:
                                    widget.highlightScrubbedBar,
                                hoverX: sliderXInChart,
                                lineColor: AppColors.mainColor,
                                isCurved: widget.isCurved,
                                showDots: widget.showDots,
                                useBars: widget.useBars,
                                barColorBuilder: widget.barColorBuilder,
                                minX: widget.minX,
                                maxX: widget.maxX,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Padding(
                      padding: EdgeInsets.only(left: yAxisWidth),
                      child: widget.chartLabels,
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 0,
                left: knobAbsoluteX - 20,
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: AppColors.mainColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Snaps the current physical slider position to the nearest underlying logical data point
  /// and fires the external callback.
  void _reportValue(double chartWidth) {
    if (widget.onValueSelected == null || widget.dataPoints.isEmpty) return;

    double minX = widget.minX ?? 0;
    double maxX = widget.maxX ?? 1440;

    if (widget.isTrend || (widget.minX == null && widget.maxX == null)) {
      minX = widget.dataPoints.map((e) => e.x.toDouble()).reduce(min);
      maxX = widget.dataPoints.map((e) => e.x.toDouble()).reduce(max);
      if (minX == maxX) maxX += 1;
    }

    final double range = maxX - minX;

    final double hoverX = _sliderPosition * chartWidth;
    final double dataX = minX + (hoverX / chartWidth) * range;

    Point? closest;
    double minDiff = double.infinity;

    for (final p in widget.dataPoints) {
      final double diff = (p.x - dataX).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = p;
      }
    }

    if (closest != null) {
      final double val = closest.y.toDouble();
      final double snappedProgress = (closest.x - minX) / range;
      widget.onValueSelected!(val, closest.x.toDouble(), snappedProgress);
    } else {
      widget.onValueSelected!(null, null, null);
    }
  }

  /// Helper to format the numeric values on the Y-Axis cleanly (e.g., converting 1000 to 1k).
  Widget _buildYLabel(double value) {
    String text;
    if (value <= 0) {
      text = "0";
    } else if (value >= 1000) {
      text = "${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k";
    } else if (value >= 20) {
      text = value.round().toString();
    } else {
      text = value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
    return Text(text, style: AppTextStyles.bodygrey.copyWith(fontSize: 10));
  }
}

/// The core canvas implementation responsible for drawing the grid, the data lines/bars,
/// the dashed average overlay, and the interactive highlight reticle.
class _LineChartPainter extends CustomPainter {
  final List<Point> dataPoints;
  final double minY;
  final double maxY;
  final double hoverX;
  final Color lineColor;
  final bool isCurved;
  final bool showDots;
  final bool useBars;
  final double? averageY;
  final bool highlightScrubbedBar;
  final Color Function(double value)? barColorBuilder;
  final double? minX;
  final double? maxX;
  final bool isTrend;

  _LineChartPainter({
    required this.dataPoints,
    required this.minY,
    required this.maxY,
    this.averageY,
    this.highlightScrubbedBar = true,
    required this.hoverX,
    required this.lineColor,
    this.isCurved = true,
    this.showDots = false,
    this.useBars = false,
    this.barColorBuilder,
    this.minX,
    this.maxX,
    required this.isTrend,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    final Paint indicatorLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;

    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint dataDotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      gridPaint,
    );

    double getY(double value) {
      final double normalized = ((value - minY) / (maxY - minY)).clamp(
        0.0,
        1.0,
      );
      return size.height - (normalized * size.height);
    }

    double usedMinX = minX ?? 0;
    double usedMaxX = maxX ?? 1440;

    if (isTrend || (minX == null && maxX == null)) {
      if (dataPoints.isNotEmpty) {
        usedMinX = dataPoints.map((e) => e.x.toDouble()).reduce(min);
        usedMaxX = dataPoints.map((e) => e.x.toDouble()).reduce(max);
        if (usedMinX == usedMaxX) usedMaxX += 1;
      }
    }
    final double xRange = usedMaxX - usedMinX;

    if (averageY != null) {
      final double avgY = getY(averageY!);
      final Paint avgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final double dashWidth = 4;
      final double dashSpace = 4;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, avgY),
          Offset(startX + dashWidth, avgY),
          avgPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    Point? focusedPoint;

    if (highlightScrubbedBar) {
      final double dataX = usedMinX + (hoverX / size.width) * xRange;
      double minDiff = double.infinity;
      for (final p in dataPoints) {
        final double diff = (p.x - dataX).abs();
        if (diff < minDiff) {
          minDiff = diff;
          focusedPoint = p;
        }
      }
    }

    if (useBars) {
      if (dataPoints.isEmpty) return;
      int startIndex = 0;

      for (int i = 0; i < dataPoints.length; i++) {
        final bool isLast = i == dataPoints.length - 1;
        bool isContiguous = false;

        final Point p = dataPoints[i];

        if (!isLast && !isTrend) {
          final next = dataPoints[i + 1];
          if (p.y == next.y &&
              (next.x - p.x) <= 1.1 &&
              !p.y.toDouble().isNaN &&
              p.y > 0) {
            isContiguous = true;
          }
        }

        final double currentVal = p.y.toDouble();

        if (!isContiguous || isLast) {
          if (!currentVal.isNaN && currentVal > 0) {
            final Point startP = dataPoints[startIndex];
            final Point endP = dataPoints[i];

            final double startX = ((startP.x - usedMinX) / xRange) * size.width;
            final double endX = ((endP.x - usedMinX) / xRange) * size.width;

            final double y = getY(currentVal);
            final double bottomY = size.height;

            double width = max(4.0, endX - startX);
            if (isTrend && endX == startX && dataPoints.isNotEmpty) {
              width = (size.width / dataPoints.length) * 0.7;
              width = max(3.5, width);
            }
            final double centerX = (startX + endX) / 2;

            final Rect barRect = Rect.fromCenter(
              center: Offset(centerX, (y + bottomY) / 2),
              width: width,
              height: bottomY - y,
            );

            final Paint barPaint = Paint()..style = PaintingStyle.fill;
            Color baseColor = lineColor.withValues(alpha: 0.6);
            if (barColorBuilder != null) {
              baseColor = barColorBuilder!(currentVal);
            }

            bool isHighlighted = false;
            if (highlightScrubbedBar && focusedPoint != null) {
              if (focusedPoint.x >= startP.x && focusedPoint.x <= endP.x) {
                isHighlighted = true;
              }
            }

            if (isHighlighted) {
              barPaint.color = baseColor.withValues(alpha: 1.0);
            } else {
              barPaint.color = baseColor;
              if (highlightScrubbedBar) {
                barPaint.color = baseColor.withValues(alpha: 0.3);
              }
            }

            final RRect rRect = RRect.fromRectAndCorners(
              barRect,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            );
            canvas.drawRRect(rRect, barPaint);
          }
          startIndex = i + 1;
        }
      }
    } else {
      final path = Path();
      bool isPreviousPointValid = false;

      double? lastValidX;
      double? lastValidY;

      for (int i = 0; i < dataPoints.length; i++) {
        final Point p = dataPoints[i];
        final double val = p.y.toDouble();

        if (val.isNaN || val <= 0) {
          isPreviousPointValid = false;
          continue;
        }

        final double x = ((p.x - usedMinX) / xRange) * size.width;
        final double y = getY(val);

        if (showDots) {
          canvas.drawCircle(Offset(x, y), 3, dataDotPaint);
        }

        if (!isPreviousPointValid) {
          path.moveTo(x, y);
          isPreviousPointValid = true;
        } else {
          if (isCurved && lastValidX != null && lastValidY != null) {
            final double controlX = (lastValidX + x) / 2;
            path.cubicTo(controlX, lastValidY, controlX, y, x, y);
          } else {
            path.lineTo(x, y);
          }
        }

        lastValidX = x;
        lastValidY = y;
      }

      canvas.drawPath(path, linePaint);

      if (focusedPoint != null) {
        final double snappedX =
            ((focusedPoint.x - usedMinX) / xRange) * size.width;
        final double snappedY = getY(focusedPoint.y.toDouble());

        canvas.drawLine(
          Offset(snappedX, snappedY),
          Offset(snappedX, size.height + 45),
          indicatorLinePaint,
        );

        Color dotBorder = lineColor;
        if (useBars && barColorBuilder != null) {
          dotBorder = barColorBuilder!(focusedPoint.y.toDouble());
        }

        final Paint dynamicDotBorderPaint = Paint()
          ..color = dotBorder
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(snappedX, snappedY), 5, dotPaint);
        canvas.drawCircle(Offset(snappedX, snappedY), 5, dynamicDotBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.hoverX != hoverX ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.showDots != showDots ||
        oldDelegate.isCurved != isCurved ||
        oldDelegate.useBars != useBars ||
        oldDelegate.barColorBuilder != barColorBuilder ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX;
  }
}

/// A specialized canvas painter drawing the background card of the chart,
/// featuring a dynamic "dent" that smoothly tracks the user's horizontal thumb slider.
class _ChartBackgroundPainter extends CustomPainter {
  final Color color;
  final double knobX;

  _ChartBackgroundPainter({required this.color, required this.knobX});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    const double cornerRadius = 24.0;
    const double dentWidth = 80.0;
    const double dentHeight = 12.0;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );

    path.lineTo(knobX + (dentWidth / 2), size.height);
    path.quadraticBezierTo(
      knobX,
      size.height - dentHeight * 2,
      knobX - (dentWidth / 2),
      size.height,
    );

    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChartBackgroundPainter oldDelegate) =>
      oldDelegate.knobX != knobX;
}
