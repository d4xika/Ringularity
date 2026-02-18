import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ble/ble_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class MonitoringSettingsSheet extends StatefulWidget {
  const MonitoringSettingsSheet({super.key});

  @override
  State<MonitoringSettingsSheet> createState() =>
      _MonitoringSettingsSheetState();
}

class _MonitoringSettingsSheetState extends State<MonitoringSettingsSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch current settings once when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleService>().readAutoSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch BleService for changes
    final bleService = context.watch<BleService>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text("Monitoring Settings", style: AppTextStyles.subtitle),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle("Heart Rate"),
                _buildSwitchTile(
                  title: "Heart Rate Monitoring",
                  subtitle: "Enable automatic periodic measurement.",
                  value: bleService.hrAutoEnabled,
                  onChanged: (bool value) {
                    bleService.setAutoHrInterval(
                      value
                          ? (bleService.hrInterval > 0
                                ? bleService.hrInterval
                                : 30)
                          : 0,
                    );
                  },
                ),
                if (bleService.hrAutoEnabled)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Measurement Interval",
                          style: AppTextStyles.bodywhite,
                        ),
                        DropdownButton<int>(
                          value: bleService.hrInterval > 0
                              ? bleService.hrInterval
                              : 30,
                          dropdownColor: AppColors.cardBackground,
                          style: AppTextStyles.bodywhite,
                          underline: Container(
                            height: 1,
                            color: AppColors.mainColor,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.mainColor,
                          ),
                          items: [5, 10, 15, 30, 45, 60].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text("$value min"),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              bleService.setAutoHrInterval(newValue);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white10),
                _buildSectionTitle("Other Sensors"),

                _buildSwitchTile(
                  title: "Stress Monitoring",
                  subtitle: "Starts periodic stress measurement.",
                  value: bleService.stressAutoEnabled,
                  onChanged: (bool value) => bleService.setAutoStress(value),
                ),
                _buildSwitchTile(
                  title: "HRV Monitoring",
                  subtitle: "Enables Scheduled HRV.",
                  value: bleService.hrvAutoEnabled,
                  onChanged: (bool value) => bleService.setAutoHrv(value),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.mainColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: AppTextStyles.bodywhite),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.mainColor,
      inactiveTrackColor: Colors.black.withOpacity(0.3),
      contentPadding: EdgeInsets.zero,
    );
  }
}
