import 'package:flutter/material.dart';

import '/../widgets/individual_activity_tile.dart';
import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gps_sheet.dart';
import 'active_session_screen.dart';

class ActivitySelectionScreen extends StatelessWidget {
  ActivitySelectionScreen({super.key});

  final Map<ActivityType, IconData> _activityIcons = {
    ActivityType.walk: Icons.directions_walk,
    ActivityType.run: Icons.directions_run,
    ActivityType.cycling: Icons.directions_bike,
    ActivityType.hiking: Icons.landscape,
    ActivityType.swimming: Icons.pool,
    ActivityType.gym: Icons.fitness_center,
    ActivityType.yoga: Icons.self_improvement,
    ActivityType.dance: Icons.music_note,
    ActivityType.pilates: Icons.accessibility_new,
    ActivityType.individual: Icons.edit_note,
  };

  @override
  Widget build(BuildContext context) {
    final types = ActivityType.values;

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
          title: const Text(
            "Start Activity",
            style: TextStyle(color: AppColors.mainColor),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: types.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final type = types[index];
            final typeName = type.toString().split('.').last.toUpperCase();

            if (type == ActivityType.individual) {
              return IndividualActivityTile(
                icon: _activityIcons[type]!,
                onArrowPressed: (customName) {
                  _showGpsSheet(context, type, customName: customName);
                },
              );
            }

            return ListTile(
              tileColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                _activityIcons[type] ?? Icons.directions_run,
                color: AppColors.mainColor,
              ),
              title: Text(
                typeName,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
              onTap: () => _showGpsSheet(context, type),
            );
          },
        ),
      ),
    );
  }

  void _showGpsSheet(
    BuildContext context,
    ActivityType type, {
    String? customName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GpsSheet(
        // Dein ausgelagertes Widget
        onYes: () {
          Navigator.pop(context);
          _showToast(context);
          _navigateToSession(
            context,
            type,
            useGps: true,
            customName: customName,
          );
        },
        onNo: () {
          Navigator.pop(context);
          _showToast(context);
          _navigateToSession(
            context,
            type,
            useGps: false,
            customName: customName,
          );
        },
      ),
    );
  }

  void _showToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please bring your phone with you!"),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.mainColor,
      ),
    );
  }

  void _navigateToSession(
    BuildContext context,
    ActivityType type, {
    required bool useGps,
    String? customName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveSessionScreen(
          type: type,
          useGps: useGps,
          customTitle: customName,
        ),
      ),
    );
  }
}
