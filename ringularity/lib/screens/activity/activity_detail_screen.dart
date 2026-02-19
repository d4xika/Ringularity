import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  final ScrollController _scrollController = ScrollController();

  final Set<Polyline> _polylines = {};
  LatLng _initialPosition = const LatLng(0, 0);

  String? _scrubbedHr;
  String? _scrubbedTime;

  @override
  void initState() {
    super.initState();
    _prepareMapData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _prepareMapData() {
    if (widget.activity.route != null && widget.activity.route!.isNotEmpty) {
      final List<LatLng> points = widget.activity.route!
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      _initialPosition = points.first;

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: AppColors.mainColor,
            width: 4,
          ),
        );
      });
    }
  }

  Future<void> _zoomToFitRoute(GoogleMapController controller) async {
    if (widget.activity.route == null || widget.activity.route!.isEmpty) return;

    final points = widget.activity.route!;

    if (points.length < 2) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          16,
        ),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLong = points.first.longitude;
    double maxLong = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLong) minLong = p.longitude;
      if (p.longitude > maxLong) maxLong = p.longitude;
    }

    if (minLat == maxLat && minLong == maxLong) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLong), 16),
      );
      return;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLong),
          northeast: LatLng(maxLat, maxLong),
        ),
        50,
      ),
    );
  }

  (double minY, double maxY) _calculateYRange(List<Point> data) {
    final validData = data.where((p) => !p.y.isNaN).toList();
    if (validData.isEmpty) return (60, 180);

    final double minVal = validData.map((p) => p.y.toDouble()).reduce(min);
    final double maxVal = validData.map((p) => p.y.toDouble()).reduce(max);

    const double padding = 5;

    return ((minVal - padding).clamp(40, double.infinity), maxVal + padding);
  }

  @override
  Widget build(BuildContext context) {
    final activityEndTime = widget.activity.date;
    final activityStartTime = activityEndTime.subtract(
      widget.activity.duration,
    );

    final startTimeStr = DateFormat('HH:mm').format(activityStartTime);
    final endTimeStr = DateFormat('HH:mm').format(activityEndTime);

    final bool hasGpsData =
        widget.activity.route != null && widget.activity.route!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/starry_night_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Activity Details", style: AppTextStyles.title),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: RawScrollbar(
          controller: _scrollController,
          thumbColor: AppColors.mainColor.withOpacity(0.6),
          radius: const Radius.circular(8),
          thickness: 6,
          thumbVisibility: true,
          trackVisibility: true,
          trackColor: Colors.white.withOpacity(0.05),
          padding: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mainColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.activity.type.icon,
                        color: AppColors.mainColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activity.typeName,
                          style: AppTextStyles.subsubtitle,
                        ),
                        Text(
                          DateFormat(
                            'd. MMMM yyyy',
                          ).format(widget.activity.date),
                          style: AppTextStyles.bodygrey,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildDetailStat("Time", "$startTimeStr - $endTimeStr"),
                    _buildDetailStat(
                      "Duration",
                      "${widget.activity.duration.inMinutes} min",
                    ),
                    if (hasGpsData) ...[
                      _buildDetailStat(
                        "Distance",
                        "${widget.activity.distanceKm.toStringAsFixed(2)} km",
                      ),
                      _buildPaceOrSpeedStat(),
                    ],
                  ],
                ),

                const SizedBox(height: 30),

                Text(
                  "Heart Rate",
                  style: AppTextStyles.subsubtitle.copyWith(
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 260,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Builder(
                    builder: (context) {
                      final List<int> rawTrace = widget.activity.hrTrace ?? [];

                      // Convert raw trace to Points
                      // Assuming evenly spaced over duration
                      final List<Point> hrPoints = [];
                      if (rawTrace.isNotEmpty) {
                        final int totalMinutes =
                            widget.activity.duration.inMinutes;
                        if (totalMinutes > 0) {
                          final double interval =
                              totalMinutes /
                              (rawTrace.length > 1 ? rawTrace.length - 1 : 1);
                          for (int i = 0; i < rawTrace.length; i++) {
                            hrPoints.add(Point(i * interval, rawTrace[i]));
                          }
                        } else {
                          // fallback if duration is 0?
                          for (int i = 0; i < rawTrace.length; i++) {
                            hrPoints.add(Point(i, rawTrace[i]));
                          }
                        }
                      }

                      final validData = hrPoints
                          .where((p) => !p.y.isNaN)
                          .toList();
                      final (minY, maxY) = _calculateYRange(hrPoints);

                      int maxHr = widget.activity.avgHeartRate;
                      if (validData.isNotEmpty) {
                        maxHr = validData.map((p) => p.y.toInt()).reduce(max);
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (_scrubbedHr != null) ...[
                                Text(
                                  "Time: $_scrubbedTime",
                                  style: AppTextStyles.bodywhite,
                                ),
                                Text(
                                  "HR: $_scrubbedHr bpm",
                                  style: AppTextStyles.bodywhite.copyWith(
                                    color: AppColors.mainColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  "Max: $maxHr",
                                  style: AppTextStyles.bodywhite,
                                ),
                                Text(
                                  "Avg: ${widget.activity.avgHeartRate}",
                                  style: AppTextStyles.bodywhite,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: validData.length < 2
                                ? const Center(
                                    child: Text(
                                      "No HR data for this session",
                                      style: AppTextStyles.bodygrey,
                                    ),
                                  )
                                : ScrubbableChart(
                                    minY: minY,
                                    maxY: maxY,
                                    dataPoints: hrPoints,
                                    chartLabels: _buildActivityChartLabels(
                                      activityStartTime,
                                      activityEndTime,
                                    ),
                                    isCurved: true,
                                    showDots: false,
                                    useBars: false,
                                    // Set X range
                                    minX: 0,
                                    maxX: widget.activity.duration.inMinutes > 0
                                        ? widget.activity.duration.inMinutes
                                              .toDouble()
                                        : 1.0,
                                    onValueSelected: (val, x, progress) {
                                      setState(() {
                                        if (val == null || x == null) {
                                          _scrubbedHr = null;
                                          _scrubbedTime = null;
                                        } else {
                                          _scrubbedHr = val.round().toString();
                                          final int scrubMinutes = x.round();
                                          final DateTime timeAtPoint =
                                              activityStartTime.add(
                                                Duration(minutes: scrubMinutes),
                                              );

                                          _scrubbedTime = DateFormat(
                                            'HH:mm',
                                          ).format(timeAtPoint);
                                        }
                                      });
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  "Map",
                  style: AppTextStyles.subsubtitle.copyWith(
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: hasGpsData
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: CameraPosition(
                              target: _initialPosition,
                              zoom: 14,
                            ),
                            polylines: _polylines,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController.complete(controller);
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  try {
                                    _zoomToFitRoute(controller);
                                  } catch (e) {
                                    debugPrint("Map zoom error: $e");
                                  }
                                },
                              );
                            },
                            zoomControlsEnabled: true,
                            myLocationEnabled: false,
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                color: Colors.white54,
                                size: 50,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "No GPS data available",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaceOrSpeedStat() {
    final duration = widget.activity.duration;
    final distanceKm = widget.activity.distanceKm;
    final type = widget.activity.type;

    if (distanceKm <= 0 || duration.inSeconds == 0) {
      if (type == ActivityType.cycling)
        return _buildDetailStat("Avg Speed", "- km/h");
      if (type == ActivityType.swimming)
        return _buildDetailStat("Avg Pace", "- /100m");
      return _buildDetailStat("Avg Pace", "- /km");
    }

    if (type == ActivityType.cycling) {
      final double hours = duration.inSeconds / 3600.0;
      final double speed = distanceKm / hours;
      return _buildDetailStat("Avg Speed", "${speed.toStringAsFixed(1)} km/h");
    } else if (type == ActivityType.swimming) {
      final double distanceMeters = distanceKm * 1000.0;
      final double hundredsOfMeters = distanceMeters / 100.0;
      final double totalMinutes = duration.inSeconds / 60.0;
      final double pace = totalMinutes / hundredsOfMeters;

      int minutes = pace.floor();
      int seconds = ((pace - minutes) * 60).round();
      if (seconds == 60) {
        minutes += 1;
        seconds = 0;
      }
      return _buildDetailStat(
        "Avg Pace",
        "$minutes'${seconds.toString().padLeft(2, '0')}'' /100m",
      );
    } else {
      final double totalMinutes = duration.inSeconds / 60.0;
      final double pace = totalMinutes / distanceKm;

      int minutes = pace.floor();
      int seconds = ((pace - minutes) * 60).round();
      if (seconds == 60) {
        minutes += 1;
        seconds = 0;
      }
      return _buildDetailStat(
        "Avg Pace",
        "$minutes'${seconds.toString().padLeft(2, '0')}'' /km",
      );
    }
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: AppTextStyles.bodywhite),
      ],
    );
  }

  Widget _buildActivityChartLabels(DateTime start, DateTime end) {
    final mid = start.add(
      Duration(minutes: end.difference(start).inMinutes ~/ 2),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('HH:mm').format(start),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        Text(
          DateFormat('HH:mm').format(mid),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        Text(
          DateFormat('HH:mm').format(end),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }
}
