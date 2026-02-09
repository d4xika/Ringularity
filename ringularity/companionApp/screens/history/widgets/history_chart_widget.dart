import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryChartWidget extends StatefulWidget {
  final List<Point> data;
  final String metricLabel; // e.g. "Heart Rate (BPM)"
  final String unit; // e.g. "bpm"
  final Color color;
  final String emptyMessage; // e.g. "No HR History Data"
  final VoidCallback onSync;
  final bool accumulateData; // If true, y values are cumulative sums
  final double? minY;
  final double? maxY;

  const HistoryChartWidget({
    super.key,
    required this.data,
    required this.metricLabel,
    required this.unit,
    required this.color,
    required this.emptyMessage,
    required this.onSync,
    this.accumulateData = false,
    this.minY,
    this.maxY,
  });

  @override
  State<HistoryChartWidget> createState() => _HistoryChartWidgetState();
}

class _HistoryChartWidgetState extends State<HistoryChartWidget> {
  // Time Domain: 0 - 1440 (Minutes in a day)
  // For Steps (96 intervals), we multiply by 15 to get minutes?
  // Steps chart used 0-96 on X axis. HR used 0-1440.
  // To unify, we should perhaps normalize everything to Minutes (0-1440)?
  // But the Steps chart X axis labels logic was: index * 15.
  // The HR chart X axis labels logic was: value.toInt() (which was minutes).
  // If I convert Steps X to minutes (x * 15) before passing, then logic is same.
  // I will assume input data X is in "Minutes from Midnight" (0-1440) for standard usage.
  // OR I can keep X generic and let caller handle conversion?
  // Steps used `_maxX = 96`. HR used `_maxX = 1440`.
  // I should probably pass `maxX` as a param or default to 1440.

  double _minX = 0;
  double _maxX = 1440;
  double _absMaxX = 1440; // Default to 24h minutes

  bool _initializedZoom = false;
  double? _touchX;

  List<FlSpot> _spots = [];
  double _calculatedMaxY = 100;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(covariant HistoryChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _processData();
    }
  }

  void _processData() {
    List<Point> sorted = List.from(widget.data);
    sorted.sort((a, b) => a.x.compareTo(b.x));

    _spots.clear();
    double maxYFound = 0;

    // Determine X scale
    // If last X > 100, assume Minutes (1440). If < 100, assume Steps (96).
    // Better: let caller specify, or detect.
    // For Steps, the X in Point is quarter-index (0-96).
    // For HR, X is minute (0-1440).
    // The previous implementation kept them in their native units.
    // Steps labels: index * 15.
    // HR labels: value.
    // I will try to support both by checking the max X in data?
    // Or just added a param `maxX` to widget.

    // Check if handling steps (small range X)
    bool isSmallRange = sorted.isNotEmpty && sorted.last.x <= 96;
    _absMaxX = isSmallRange ? 96.0 : 1440.0;
    _maxX = _absMaxX; // Reset to full view initially

    double currentTotal = 0;
    for (var point in sorted) {
      double yVal = point.y.toDouble();
      if (widget.accumulateData) {
        currentTotal += yVal;
        yVal = currentTotal;
      }
      _spots.add(FlSpot(point.x.toDouble(), yVal));
      if (yVal > maxYFound) maxYFound = yVal;
    }

    _calculatedMaxY = (widget.maxY) ?? (maxYFound * 1.1 + 10);
    // Ensure min range
    if (_calculatedMaxY < 10) _calculatedMaxY = 10;

    // Auto-Zoom Logic (One time or on new data?)
    // "Relaxed Zoom" around data
    if (!_initializedZoom && _spots.isNotEmpty) {
      double firstX = _spots.first.x;
      double lastX = _spots.last.x;

      double range = isSmallRange ? 8.0 : 120.0; // 2 hours
      double visibleMin = isSmallRange ? 24.0 : 240.0; // 6h / 4h

      _minX = (firstX - range).clamp(0, _absMaxX);
      _maxX = (lastX + range).clamp(0, _absMaxX);

      if (_maxX - _minX < visibleMin) {
        double center = (firstX + lastX) / 2;
        double half = visibleMin / 2;
        _minX = (center - half).clamp(0, _absMaxX);
        _maxX = (center + half).clamp(0, _absMaxX);
      }
      _initializedZoom = true;
    }
  }

  void _onViewChange(double minX, double maxX) {
    setState(() {
      _minX = minX;
      _maxX = maxX;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.emptyMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: widget.onSync,
              child: const Text("Sync Data"),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.metricLabel,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: "Reset Zoom",
                onPressed: () {
                  setState(() {
                    _minX = 0;
                    _maxX = _absMaxX;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              double chartHeight =
                  constraints.maxHeight - 22; // space for labels

              return Stack(
                children: [
                  _ZoomableChart(
                    minX: _minX,
                    maxX: _maxX,
                    maxLimit: _absMaxX,
                    onViewChange: _onViewChange,
                    onTouchUpdate: (relX) {
                      setState(() {
                        _touchX = relX;
                      });
                    },
                    onTouchEnd: () {
                      setState(() {
                        _touchX = null;
                      });
                    },
                    child: LineChart(
                      LineChartData(
                        minX: _minX,
                        maxX: _maxX,
                        minY: widget.minY ?? 0,
                        maxY: _calculatedMaxY,
                        lineTouchData: const LineTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: (_maxX - _minX) / 5,
                              getTitlesWidget: (value, meta) {
                                int v = value.toInt();
                                if (v < _minX || v > _maxX)
                                  return const SizedBox();

                                int totalMinutes;
                                if (_absMaxX == 96) {
                                  // Steps mode (quarters)
                                  totalMinutes = v * 15;
                                } else {
                                  // Minutes mode
                                  totalMinutes = v;
                                }

                                int h = totalMinutes ~/ 60;
                                int m = totalMinutes % 60;
                                if (h >= 24) h %= 24;
                                String text =
                                    "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(text,
                                      style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: widget.color,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: widget.color.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_touchX != null && _spots.isNotEmpty)
                    _buildTooltip(constraints.maxWidth, chartHeight),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(double width, double height) {
    if (_touchX == null) return const SizedBox();

    double chartWidthRange = _maxX - _minX;
    double touchValue = _minX + (_touchX! * chartWidthRange);

    // Find nearest
    FlSpot nearestSpot = _spots.first;
    double minDist = double.infinity;
    for (var spot in _spots) {
      double d = (spot.x - touchValue).abs();
      if (d < minDist) {
        minDist = d;
        nearestSpot = spot;
      }
    }

    double minY = widget.minY ?? 0;
    double maxY = _calculatedMaxY;

    double relativeY = (nearestSpot.y - minY) / (maxY - minY);
    if (relativeY > 1.0) relativeY = 1.0;
    if (relativeY < 0.0) relativeY = 0.0;

    double dotTop = (1.0 - relativeY) * height;

    double relativeSpotX = (nearestSpot.x - _minX) / (_maxX - _minX);
    double dotLeft = relativeSpotX * width;

    if (dotLeft < 0 || dotLeft > width) return const SizedBox();

    // Time String
    int xVal = nearestSpot.x.toInt();
    int totalMinutes = (_absMaxX == 96) ? xVal * 15 : xVal;
    int h = totalMinutes ~/ 60;
    int m = totalMinutes % 60;
    String timeStr =
        "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

    return Stack(
      children: [
        Positioned(
          left: dotLeft - 6,
          top: dotTop - 6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black26)
              ],
            ),
          ),
        ),
        Positioned(
          left: dotLeft - 32,
          top: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$timeStr\n${nearestSpot.y.toInt()} ${widget.unit}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomableChart extends StatefulWidget {
  final Widget child;
  final double minX;
  final double maxX;
  final double maxLimit;
  final Function(double, double) onViewChange;
  final Function(double)? onTouchUpdate;
  final Function()? onTouchEnd;

  const _ZoomableChart({
    required this.child,
    required this.minX,
    required this.maxX,
    required this.maxLimit,
    required this.onViewChange,
    this.onTouchUpdate,
    this.onTouchEnd,
  });

  @override
  State<_ZoomableChart> createState() => _ZoomableChartState();
}

class _ZoomableChartState extends State<_ZoomableChart> {
  double? _startMinX;
  double? _startMaxX;
  double? _startNormFocalX;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _startMinX = widget.minX;
        _startMaxX = widget.maxX;
        final box = context.findRenderObject() as RenderBox;
        final localPoint = box.globalToLocal(details.focalPoint);
        _startNormFocalX = localPoint.dx / box.size.width;
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        final box = context.findRenderObject() as RenderBox;
        final localPoint = box.globalToLocal(details.focalPoint);
        final currentNormFocalX = localPoint.dx / box.size.width;

        if (details.pointerCount == 1) {
          widget.onTouchUpdate?.call(currentNormFocalX);
          return;
        }

        widget.onTouchEnd?.call();

        if (_startMinX == null ||
            _startMaxX == null ||
            _startNormFocalX == null) return;

        double startRange = _startMaxX! - _startMinX!;
        double newRange = startRange / details.scale;

        // Limits
        if (newRange < widget.maxLimit * 0.05)
          newRange = widget.maxLimit * 0.05;
        if (newRange > widget.maxLimit) newRange = widget.maxLimit;

        double dataPointAtFocal =
            _startMinX! + (startRange * _startNormFocalX!);
        double newMin = dataPointAtFocal - (newRange * currentNormFocalX);
        double newMax = newMin + newRange;

        if (newMin < 0) {
          newMin = 0;
          newMax = newRange;
        }
        if (newMax > widget.maxLimit) {
          newMax = widget.maxLimit;
          newMin = widget.maxLimit - newRange;
        }

        widget.onViewChange(newMin, newMax);
      },
      onScaleEnd: (details) {
        widget.onTouchEnd?.call();
      },
      child: widget.child,
    );
  }
}
