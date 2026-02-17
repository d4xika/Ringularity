import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/activity/gps_sheet.dart';
import '../../widgets/activity/individual_activity_tile.dart';
import 'active_session_screen.dart';

class ActivitySelectionScreen extends StatelessWidget {
  const ActivitySelectionScreen({super.key});

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
                icon: type.icon,
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
              leading: Icon(type.icon, color: AppColors.mainColor),
              title: Text(typeName, style: AppTextStyles.bodywhite),
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
        onPositivePressed: () {
          Navigator.pop(context);
          _navigateToSession(
            context,
            type,
            useGps: true,
            customName: customName,
          );
        },
        onNegativePressed: () {
          Navigator.pop(context);
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
