import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  final Set<Polyline> _polylines = {};
  LatLng _initialPosition = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _prepareMapData();
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

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat(
      'HH:mm',
    ).format(widget.activity.date.subtract(widget.activity.duration));
    final endTime = DateFormat('HH:mm').format(widget.activity.date);

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
        body: SingleChildScrollView(
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
                        DateFormat('d. MMMM yyyy').format(widget.activity.date),
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
                  _buildDetailStat("Time", "$startTime - $endTime"),
                  _buildDetailStat(
                    "Duration",
                    "${widget.activity.duration.inMinutes} min",
                  ),
                  _buildDetailStat(
                    "Distance",
                    "${widget.activity.distanceKm.toStringAsFixed(2)} km",
                  ),
                  _buildDetailStat("Avg Pace", "5'36'' /km"),
                  _buildDetailStat(
                    "Avg HR",
                    "${widget.activity.avgHeartRate} bpm",
                  ),
                  _buildDetailStat("Calories", "320 kcal"),
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
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text("Max: 168", style: AppTextStyles.bodywhite),
                        Text("Avg: 153", style: AppTextStyles.bodywhite),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      height: 100,
                      color: Colors.white.withOpacity(0.05),
                      child: const Center(
                        child: Text(
                          "Chart Placeholder",
                          style: AppTextStyles.bodygrey,
                        ),
                      ),
                    ),
                  ],
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
                color: Colors.grey[800],
                child:
                    (widget.activity.route != null &&
                        widget.activity.route!.isNotEmpty)
                    ? GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: CameraPosition(
                          target: _initialPosition,
                          zoom: 14,
                        ),
                        polylines: _polylines,

                        onMapCreated: (GoogleMapController controller) {
                          _mapController.complete(controller);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            try {
                              _zoomToFitRoute(controller);
                            } catch (e) {
                              debugPrint("Map zoom error: $e");
                            }
                          });
                        },
                        zoomControlsEnabled: true,
                        myLocationEnabled: false,
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
    );
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
}
