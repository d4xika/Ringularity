import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';

/// Displays a recorded GPS route on an interactive OpenStreetMap.
///
/// Fits the initial map view to the complete route and keeps the OpenStreetMap
/// attribution visible with a link to its copyright and licence information.
class ActivityRouteMap extends StatelessWidget {
  /// Chronological GPS positions of the activity. Must contain at least one point.
  final List<Position> route;

  /// Optional tile provider for supplying map images, such as local test tiles.
  ///
  /// When omitted, flutter_map loads OpenStreetMap tiles over the network and
  /// uses its default caching behaviour.
  final TileProvider? tileProvider;

  /// Creates a route map for an activity with recorded GPS positions.
  const ActivityRouteMap({super.key, required this.route, this.tileProvider});

  /// Builds the map tiles, recorded route overlay, and linked attribution.
  ///
  /// Caps the initial zoom so single-point and stationary recordings remain
  /// viewable while longer routes are fitted with padding around their bounds.
  @override
  Widget build(BuildContext context) {
    final points = route
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: 16,
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(32),
          maxZoom: 16,
        ),
        minZoom: 1,
        maxZoom: 19,
        backgroundColor: AppColors.cardBackground,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.ringularity.mobile',
          tileProvider: tileProvider,
          maxNativeZoom: 19,
          panBuffer: 0,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: AppColors.mainColor,
              strokeWidth: 4,
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Material(
            color: AppColors.cardBackground,
            child: InkWell(
              onTap: () {
                launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
