import 'package:flutter/material.dart';

// import 'dart:math'; // Unused
import '../../theme/app_colors.dart';

class ScrubbableChart extends StatefulWidget {
  final List<double> dataPoints;
  final Widget chartLabels;
  final double maxY;
  final bool isCurved;
  final bool showDots;

  /// Optional limit for the slider (0.0 to 1.0).
  /// If provided, the slider cannot be dragged past this point.
  final double? limitX;

  /// Callback when scrubbing, returns the interpolated value and progress (0.0 to 1.0).
  /// Returns nulls if scrubbing stops or is in a gap.
  final void Function(double? value, double? progress)? onValueSelected;

  const ScrubbableChart({
    super.key,
    required this.dataPoints,
    required this.chartLabels,
    required this.maxY,
    this.limitX,
    this.onValueSelected,
    this.isCurved = true,
    this.showDots = false,
    this.useBars = false,
    this.barColorBuilder,
  });

  final bool useBars;
  final Color Function(double value)? barColorBuilder;

  @override
  State<ScrubbableChart> createState() => _ScrubbableChartState();
}

class _ScrubbableChartState extends State<ScrubbableChart> {
  double _sliderPosition = 0.5;

  // KONSTANTEN FÜR DAS LAYOUT
  final double yAxisWidth = 40.0; // Breite der Y-Achse links
  final double chartPaddingLeft = 10.0; // Abstand links
  final double chartPaddingRight = 20.0; // Abstand rechts
  final double chartPaddingBottom = 50.0; // Platz unten für den Knob

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              widget.onValueSelected?.call(null, null);
            },
            onTapDown: (details) {
              updatePosition(details.localPosition.dx);
            },
            onTapUp: (details) {
              widget.onValueSelected?.call(null, null);
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
                    chartPaddingBottom,
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
                                            widget.maxY * 0.5,
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        child: _buildYLabel(0),
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
                                  hoverX:
                                      sliderXInChart, // Position im Chart-Koordinatensystem
                                  lineColor: AppColors.mainColor,
                                  isCurved: widget.isCurved,
                                  showDots: widget.showDots,
                                  useBars: widget.useBars,
                                  barColorBuilder: widget.barColorBuilder,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
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

    final double stepX = chartWidth / (widget.dataPoints.length - 1);
    final double hoverX = _sliderPosition * chartWidth;

    // Find nearest index
    int index = (hoverX / stepX).round();
    if (index < 0) index = 0;
    if (index >= widget.dataPoints.length) index = widget.dataPoints.length - 1;

    final double val = widget.dataPoints[index];

    if (!val.isNaN) {
      // Report Snapped Value
      // Also report snapped progress so the time label snaps to the grid
      final double snappedProgress = index / (widget.dataPoints.length - 1);
      widget.onValueSelected!(val, snappedProgress);
    } else {
      // In a gap (NaN)
      widget.onValueSelected!(null, null);
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
// ... (Importe und ScrubbableChart Klasse bleiben gleich)

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double maxY;
  final double hoverX;
  final Color lineColor;
  final bool isCurved;
  final bool showDots;
  final bool useBars;
  final Color Function(double value)? barColorBuilder;

  _LineChartPainter({
    required this.dataPoints,
    required this.maxY,
    required this.hoverX,
    required this.lineColor,
    this.isCurved = true,
    this.showDots = false,
    this.useBars = false,
    this.barColorBuilder,
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

    final stepX = size.width / (dataPoints.length - 1);

    double getY(double value) {
      final double normalized = (value / maxY).clamp(0.0, 1.0);
      return size.height - (normalized * size.height);
    }

    if (useBars) {
      // Draw Bars
      for (int i = 0; i < dataPoints.length; i++) {
        final double currentVal = dataPoints[i];
        if (currentVal.isNaN || currentVal <= 0) continue;

        final double x = i * stepX;
        final double y = getY(currentVal);
        final double bottomY = size.height;

        // Bar width - leave some gap
        double barWidth = stepX * 0.8;
        if (barWidth < 2) barWidth = 2; // Minimum visible width

        final Rect barRect = Rect.fromCenter(
          center: Offset(x, (y + bottomY) / 2),
          width: barWidth,
          height: bottomY - y,
        );

        final Paint barPaint = Paint()..style = PaintingStyle.fill;
        if (barColorBuilder != null) {
          barPaint.color = barColorBuilder!(currentVal);
        } else {
          barPaint.color = lineColor.withOpacity(0.6);
        }

        // Draw rounded rect top
        final RRect rRect = RRect.fromRectAndCorners(
          barRect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rRect, barPaint);
      }
      // Continue to draw interaction indicator...
    } else {
      // 2. Pfad (Kurve) - ONLY IF NOT BARS
      final path = Path();
      bool isPathActive = false;

      for (int i = 0; i < dataPoints.length; i++) {
        final double currentVal = dataPoints[i];

        // Draw Dot if enabled and value is valid
        if (showDots && !currentVal.isNaN) {
          final double x = i * stepX;
          final double y = getY(currentVal);
          canvas.drawCircle(Offset(x, y), 3, dataDotPaint);
        }

        if (i < dataPoints.length - 1) {
          final double nextVal = dataPoints[i + 1];

          if (!currentVal.isNaN && !nextVal.isNaN) {
            final double x1 = i * stepX;
            final double y1 = getY(currentVal);
            final double x2 = (i + 1) * stepX;
            final double y2 = getY(nextVal);

            if (!isPathActive) {
              path.moveTo(x1, y1);
              isPathActive = true;
            }

            if (isCurved) {
              final double controlX = (x1 + x2) / 2;
              path.cubicTo(controlX, y1, controlX, y2, x2, y2);
            } else {
              path.lineTo(x2, y2);
            }
          } else {
            isPathActive = false;
          }
        }
      }

      // Only draw stroke
      canvas.drawPath(path, linePaint);
    }

    // 3. Interaktion (Vertikale Linie & Punkt)

    // Find nearest index
    // stepX is already defined above
    int index = (hoverX / stepX).round();
    if (index < 0) index = 0;
    if (index >= dataPoints.length) index = dataPoints.length - 1;

    final double val = dataPoints[index];

    if (!val.isNaN) {
      final double snappedX = index * stepX;
      final double snappedY = getY(val);

      // --- KORREKTUR HIER ---
      // Wir zeichnen die Linie von der Kurve (hoverY) nach unten.
      // "size.height" ist die Unterkante des Graphen.
      // Darunter sind ca. 10px Platz + Labels (ca. 15px) + Padding zum Knob.
      // Mit "+ 45" reichen wir genau tief genug, um den Knob zu berühren/hinter ihm zu verschwinden,
      // ragen aber nicht aus dem Widget heraus.
      canvas.drawLine(
        Offset(snappedX, snappedY),
        Offset(snappedX, size.height + 45),
        indicatorLinePaint,
      );

      // Punkt auf der Kurve
      // Punkt auf der Kurve
      Color dotBorder = lineColor;
      if (useBars && barColorBuilder != null) {
        dotBorder = barColorBuilder!(val);
      }

      final Paint dynamicDotBorderPaint = Paint()
        ..color = dotBorder
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(snappedX, snappedY), 5, dotPaint);
      canvas.drawCircle(Offset(snappedX, snappedY), 5, dynamicDotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.hoverX != hoverX ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.showDots != showDots ||
        oldDelegate.isCurved != isCurved ||
        oldDelegate.useBars != useBars ||
        oldDelegate.barColorBuilder != barColorBuilder;
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
