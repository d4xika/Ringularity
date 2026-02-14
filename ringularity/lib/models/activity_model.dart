import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum ActivityType {
  walk,
  run,
  cycling,
  hiking,
  swimming,
  gym,
  yoga,
  dance,
  pilates,
  individual,
}

extension ActivityTypeIcon on ActivityType {
  IconData get icon {
    switch (this) {
      case ActivityType.walk:
        return Icons.directions_walk;
      case ActivityType.run:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.hiking:
        return Icons.landscape;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.gym:
        return Icons.fitness_center;
      case ActivityType.yoga:
        return Icons.self_improvement;
      case ActivityType.dance:
        return Icons.music_note;
      case ActivityType.pilates:
        return Icons.accessibility_new;
      case ActivityType.individual:
        return Icons.edit_note;
    }
  }
}

class ActivityModel {
  final ActivityType type;
  final String? customTitle;
  final DateTime date;
  final Duration duration;
  final double distanceKm;
  final int avgHeartRate;
  final int steps;
  final List<int>? hrTrace;
  final List<Position>? route;

  ActivityModel({
    required this.type,
    this.customTitle,
    required this.date,
    required this.duration,
    required this.distanceKm,
    required this.avgHeartRate,
    this.steps = 0,
    this.hrTrace,
    this.route,
  });

  String get typeName {
    if (type == ActivityType.individual &&
        customTitle != null &&
        customTitle!.isNotEmpty) {
      return customTitle!;
    }
    return type.toString().split('.').last.toUpperCase();
  }
}
