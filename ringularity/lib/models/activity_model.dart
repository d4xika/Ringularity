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
        return Icons.auto_awesome;
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

  // UPLOAD ZUM BACKEND & LOKALES SPEICHERN
  Map<String, dynamic> toJson() {
    return {
      // Exakt die Namen, die 'entry[:key]' in deinem Rails-Controller erwartet!
      'type': type.name,
      'customTitle': customTitle,
      'date': date.toUtc().toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'distanceKm': distanceKm,
      'avgHeartRate': avgHeartRate,
      'steps': steps,
      'hrTrace': hrTrace,
      'route': route?.map((p) => p.toJson()).toList(),
    };
  }

  // DOWNLOAD VOM BACKEND & LOKALES LADEN
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    // Hilfsfunktionen für sicheres Parsen
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ActivityModel(
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['activity_type'] || e.name == json['type'],
        orElse: () => ActivityType.walk,
      ),
      customTitle: json['custom_title'] ?? json['customTitle'],

      date: DateTime.parse(json['recorded_at'] ?? json['date']).toLocal(),

      duration: Duration(
        seconds: parseInt(json['duration'] ?? json['durationSeconds']),
      ),

      distanceKm: parseDouble(json['distance'] ?? json['distanceKm']),

      avgHeartRate: parseInt(json['avg_heart_rate'] ?? json['avgHeartRate']),

      steps: parseInt(json['steps']),

      hrTrace: (json['hr_trace'] ?? json['hrTrace']) != null
          ? List<int>.from(json['hr_trace'] ?? json['hrTrace'])
          : null,

      route: json['route'] != null
          ? (json['route'] as List)
                .map((p) => Position.fromMap(Map<String, dynamic>.from(p)))
                .toList()
          : null,
    );
  }
}
