import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';
import '../../theme/app_colors.dart';

class ScrubbableChart extends StatefulWidget {
  final List<double> dataPoints;
  final Widget chartLabels;
  final double maxY;

  const ScrubbableChart({
    super.key,
    required this.dataPoints,
    required this.chartLabels,
    required this.maxY,
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
  final double chartPaddingBottom = 50.0; // Platz unten für den Knob

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        
        // Die Breite, in der sich der Chart tatsächlich befindet
        final double chartDrawWidth = totalWidth - yAxisWidth - chartPaddingLeft - chartPaddingRight;
        
        // Berechnung der Positionen
        // 1. Wo ist der Slider relativ zum Chart (0.0 bis chartDrawWidth)?
        final double sliderXInChart = _sliderPosition * chartDrawWidth;

        // 2. Wo ist der Slider absolut im Container (für den Knob)?
        // Start = PaddingLeft + YAxisWidth
        final double knobAbsoluteX = chartPaddingLeft + yAxisWidth + sliderXInChart;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Stack(
            clipBehavior: Clip.none, // WICHTIG: Erlaubt Zeichnen über den Rand
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
                padding: EdgeInsets.fromLTRB(chartPaddingLeft, 20, chartPaddingRight, chartPaddingBottom),
                child: Column(
                  children: [
                    // --- OBERER TEIL: Y-Achse + Graph ---
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A) Y-Achse
                          SizedBox(
                            width: yAxisWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start, // Linksbündig
                              children: [
                                _buildYLabel(widget.maxY),
                                _buildYLabel(widget.maxY * 0.5),
                                _buildYLabel(0),
                              ],
                            ),
                          ),
                          
                          // B) Der Graph
                          Expanded(
                            child: CustomPaint(
                              painter: _LineChartPainter(
                                dataPoints: widget.dataPoints,
                                maxY: widget.maxY,
                                hoverX: sliderXInChart, // Position im Chart-Koordinatensystem
                                lineColor: AppColors.mainColor,
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
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      // Neue absolute Position berechnen
                      double newKnobX = knobAbsoluteX + details.delta.dx;
                      
                      // Grenzen berechnen
                      double minX = chartPaddingLeft + yAxisWidth;
                      double maxX = totalWidth - chartPaddingRight;

                      // Clamp
                      if (newKnobX < minX) newKnobX = minX;
                      if (newKnobX > maxX) newKnobX = maxX;

                      // Zurückrechnen in 0..1 für den SliderState
                      _sliderPosition = (newKnobX - minX) / chartDrawWidth;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    return Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold));
  }
}

// --- DER PAINTER ---
// ... (Importe und ScrubbableChart Klasse bleiben gleich)

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double maxY;
  final double hoverX;
  final Color lineColor;

  _LineChartPainter({
    required this.dataPoints,
    required this.maxY,
    required this.hoverX,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [lineColor.withValues(alpha: 0.3), lineColor.withValues(alpha: 0.0)],
      );

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    // Linie: Weiß, etwas transparenter, damit sie dezent wirkt
    final Paint indicatorLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6) 
      ..strokeWidth = 2.0;

    final Paint dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final Paint dotBorderPaint = Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke;

    // 1. Grid
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    // 2. Pfad (Kurve)
    final path = Path();
    final stepX = size.width / (dataPoints.length - 1);

    double getY(double value) {
      double normalized = (value / maxY).clamp(0.0, 1.0);
      return size.height - (normalized * size.height);
    }

    path.moveTo(0, getY(dataPoints[0]));

    for (int i = 0; i < dataPoints.length - 1; i++) {
      double x1 = i * stepX;
      double y1 = getY(dataPoints[i]);
      double x2 = (i + 1) * stepX;
      double y2 = getY(dataPoints[i + 1]);

      double controlX = (x1 + x2) / 2;
      
      // Smooth Curve
      path.cubicTo(controlX, y1, controlX, y2, x2, y2);
    }

    // Füllung & Linie zeichnen
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // 3. Interaktion (Vertikale Linie & Punkt)
    
    // Y-Position auf der Kurve berechnen
    int indexLeft = (hoverX / stepX).floor();
    if (indexLeft < 0) indexLeft = 0;
    if (indexLeft >= dataPoints.length - 1) indexLeft = dataPoints.length - 2;
    
    double percent = (hoverX - (indexLeft * stepX)) / stepX;
    
    double yLeft = getY(dataPoints[indexLeft]);
    double yRight = getY(dataPoints[indexLeft + 1]);
    
    // Cosine Interpolation für weichen Übergang des Punktes
    double mu2 = (1 - cos(percent * 3.1415927)) / 2;
    double hoverY = (yLeft * (1 - mu2) + yRight * mu2);

    // --- KORREKTUR HIER ---
    // Wir zeichnen die Linie von der Kurve (hoverY) nach unten.
    // "size.height" ist die Unterkante des Graphen.
    // Darunter sind ca. 10px Platz + Labels (ca. 15px) + Padding zum Knob.
    // Mit "+ 45" reichen wir genau tief genug, um den Knob zu berühren/hinter ihm zu verschwinden,
    // ragen aber nicht aus dem Widget heraus.
    canvas.drawLine(Offset(hoverX, hoverY), Offset(hoverX, size.height + 45), indicatorLinePaint);

    // Punkt auf der Kurve
    canvas.drawCircle(Offset(hoverX, hoverY), 5, dotPaint);
    canvas.drawCircle(Offset(hoverX, hoverY), 5, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.hoverX != hoverX || oldDelegate.dataPoints != dataPoints;
  }
}

// (_ChartBackgroundPainter bleibt unverändert)
class _ChartBackgroundPainter extends CustomPainter {
  final Color color;
  final double knobX;
  _ChartBackgroundPainter({required this.color, required this.knobX});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    const double cornerRadius = 24.0;
    const double dentWidth = 80.0;
    const double dentHeight = 12.0;
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);
    path.lineTo(knobX + (dentWidth / 2), size.height);
    path.quadraticBezierTo(knobX, size.height - dentHeight * 2, knobX - (dentWidth / 2), size.height);
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _ChartBackgroundPainter oldDelegate) => oldDelegate.knobX != knobX;
}