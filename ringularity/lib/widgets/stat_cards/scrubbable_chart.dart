import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ScrubbableChart extends StatefulWidget {
  final List<Point> dataPoints;
  final Widget chartLabels;
  final double minY;
  final double maxY;
  final bool isCurved;
  final bool showDots;

  /// Optional limit for the slider (0.0 to 1.0).
  /// If provided, the slider cannot be dragged past this point.
  final double? limitX;

  /// Callback when scrubbing, returns the interpolated value and progress (0.0 to 1.0).
  /// Returns nulls if scrubbing stops or is in a gap.
  final void Function(double? value, double? x, double? progress)?
  onValueSelected;

  final double? averageY;
  final bool highlightScrubbedBar;
  final bool useBars;
  final Color Function(double value)? barColorBuilder;

  final double? minX;
  final double? maxX;

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
  });

  @override
  State<ScrubbableChart> createState() => _ScrubbableChartState();
}

class _ScrubbableChartState extends State<ScrubbableChart> {
  double _sliderPosition = 0.5;

  // KONSTANTEN FÜR DAS LAYOUT
  final double yAxisWidth = 40.0; // Breite der Y-Achse links
  final double chartPaddingLeft = 10.0; // Abstand links
  final double chartPaddingRight = 20.0; // Abstand rechts
  final double chartPaddingBottom = 30.0; // Platz unten für den Knob

  @override
  void initState() {
    super.initState();
    // Enforce initial limit if needed
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
    return Container(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;

          // Die Breite, in der sich der Chart tatsächlich befindet
          final double chartDrawWidth =
              availableWidth -
              yAxisWidth -
              chartPaddingLeft -
              chartPaddingRight;

          // Berechnung der Positionen
          // 1. Wo ist der Slider relativ zum Chart (0.0 bis chartDrawWidth)?
          final double sliderXInChart = _sliderPosition * chartDrawWidth;

          // 2. Wo ist der Slider absolut im Container (für den Knob)?
          // Start = PaddingLeft + YAxisWidth
          final double knobAbsoluteX =
              chartPaddingLeft + yAxisWidth + sliderXInChart;

          // Helper to update position from local X coordinate
          void updatePosition(double localX) {
            final double startX = chartPaddingLeft + yAxisWidth;
            final double relativeX = localX - startX;
            double newPos = relativeX / chartDrawWidth;

            // Clamp 0..1
            if (newPos < 0.0) newPos = 0.0;
            if (newPos > 1.0) newPos = 1.0;

            // Check Limit
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
              clipBehavior:
                  Clip.none, // WICHTIG: Erlaubt Zeichnen über den Rand
              children: [
                // 1. Hintergrund (Delle)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChartBackgroundPainter(
                      color: AppColors.cardBackground,
                      knobX: knobAbsoluteX,
                    ),
                  ),
                ),

                // 2. Inhalt (Y-Achse, Chart, X-Labels)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    chartPaddingLeft,
                    20,
                    chartPaddingRight,
                    45, // Increased bottom padding for Knob
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
                                          top:
                                              (boxConstraints.maxHeight / 2) -
                                              7,
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
                                  averageY: widget.averageY,
                                  highlightScrubbedBar:
                                      widget.highlightScrubbedBar,
                                  hoverX:
                                      sliderXInChart, // Position im Chart-Koordinatensystem
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

                      // --- UNTERER TEIL: X-Achse Labels ---
                      Padding(
                        padding: EdgeInsets.only(left: yAxisWidth),
                        child: widget.chartLabels,
                      ),
                    ],
                  ),
                ),

                // 3. Der Knob (Weißer Kreis)
                // Er liegt im Stack als letztes, also GANZ OBEN -> verdeckt die Linie
                Positioned(
                  bottom: 0,
                  // Wir zentrieren den 40px Kreis: Position - Radius (20)
                  left: knobAbsoluteX - 20,
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.mainColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
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
      ),
    );
  }

  void _reportValue(double chartWidth) {
    if (widget.onValueSelected == null || widget.dataPoints.isEmpty) return;

    // Use provided minX/maxX or calculate from data
    double minX = widget.minX ?? 0;
    double maxX = widget.maxX ?? 1440;

    if (widget.minX == null &&
        widget.maxX == null &&
        widget.dataPoints.isNotEmpty) {
      // Auto-range
      minX = widget.dataPoints.map((e) => e.x.toDouble()).reduce(min);
      maxX = widget.dataPoints.map((e) => e.x.toDouble()).reduce(max);
      if (minX == maxX) maxX += 1;
    }

    final double range = maxX - minX;

    // Find point closest to hoverX
    // hoverX is pixel position. Convert to data-X.
    final double hoverX = _sliderPosition * chartWidth;
    final double dataX = minX + (hoverX / chartWidth) * range;

    // Find closest point
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
      // Calculate progress based on actual X of the point relative to range
      final double snappedProgress = (closest.x - minX) / range;
      widget.onValueSelected!(val, closest.x.toDouble(), snappedProgress);
    } else {
      widget.onValueSelected!(null, null, null);
    }
  }

  Widget _buildYLabel(double value) {
    String text;
    if (value >= 1000) {
      text = "${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k";
    } else if (value % 1 == 0) {
      text = value.toInt().toString();
    } else {
      text = value.toStringAsFixed(1);
    }
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// --- DER PAINTER ---

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
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final Paint indicatorLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.0;

    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint dataDotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // 1. Grid
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

    // Determine X Range
    double usedMinX = minX ?? 0;
    double usedMaxX = maxX ?? 1440;

    if (minX == null && maxX == null) {
      usedMinX = dataPoints.map((e) => e.x.toDouble()).reduce(min);
      usedMaxX = dataPoints.map((e) => e.x.toDouble()).reduce(max);
      if (usedMinX == usedMaxX) usedMaxX += 1;
    }
    final double xRange = usedMaxX - usedMinX;

    // 1b. Average Line (Dashed)
    if (averageY != null) {
      final double avgY = getY(averageY!);
      final Paint avgPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
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

    // Calculate focused point for highlight
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
      // Draw Bars
      for (int i = 0; i < dataPoints.length; i++) {
        final Point p = dataPoints[i];
        final double currentVal = p.y.toDouble();
        if (currentVal.isNaN || currentVal <= 0) continue;

        // Map X to width
        final double x = ((p.x - usedMinX) / xRange) * size.width;
        final double y = getY(currentVal);
        final double bottomY = size.height;

        final double barWidth = 4.0;

        final Rect barRect = Rect.fromCenter(
          center: Offset(x, (y + bottomY) / 2),
          width: barWidth,
          height: bottomY - y,
        );

        final Paint barPaint = Paint()..style = PaintingStyle.fill;
        Color baseColor = lineColor.withOpacity(0.6);

        if (barColorBuilder != null) {
          baseColor = barColorBuilder!(currentVal);
        }

        // Highlight Logic
        if (highlightScrubbedBar && focusedPoint == p) {
          barPaint.color = baseColor.withOpacity(1.0);
        } else {
          barPaint.color = baseColor;
          if (highlightScrubbedBar) barPaint.color = baseColor.withOpacity(0.3);
        }

        final RRect rRect = RRect.fromRectAndCorners(
          barRect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rRect, barPaint);
      }
    } else {
      // 2. Pfad (Kurve)
      final path = Path();

      for (int i = 0; i < dataPoints.length; i++) {
        final Point p = dataPoints[i];
        final double val = p.y.toDouble();
        final double x = ((p.x - usedMinX) / xRange) * size.width;
        final double y = getY(val);

        // Draw Dot
        if (showDots && !val.isNaN) {
          canvas.drawCircle(Offset(x, y), 3, dataDotPaint);
        }

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final Point prev = dataPoints[i - 1];
          final double prevX = ((prev.x - usedMinX) / xRange) * size.width;
          final double prevY = getY(prev.y.toDouble());

          if (isCurved) {
            final double controlX = (prevX + x) / 2;
            path.cubicTo(controlX, prevY, controlX, y, x, y);
          } else {
            path.lineTo(x, y);
          }
        }
      }

      canvas.drawPath(path, linePaint);

      // 3. Interaktion (Vertikale Linie & Punkt)
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
