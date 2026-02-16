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

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'customTitle': customTitle,
      'date': date.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'distanceKm': distanceKm,
      'avgHeartRate': avgHeartRate,
      'steps': steps,
      'hrTrace': hrTrace,
      'route': route?.map((p) => p.toJson()).toList(),
    };
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.walk,
      ),
      customTitle: json['customTitle'],
      date: DateTime.parse(json['date']),
      duration: Duration(seconds: json['durationSeconds'] ?? 0),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      avgHeartRate: json['avgHeartRate'] as int? ?? 0,
      steps: json['steps'] as int? ?? 0,

      hrTrace: json['hrTrace'] != null ? List<int>.from(json['hrTrace']) : null,

      route: json['route'] != null
          ? (json['route'] as List)
                .map((p) => Position.fromMap(Map<String, dynamic>.from(p)))
                .toList()
          : null,
    );
  }
}
