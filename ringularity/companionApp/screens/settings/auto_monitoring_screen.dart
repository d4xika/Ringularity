import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class AutoMonitoringScreen extends StatelessWidget {
  const AutoMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BleService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Automatic Monitoring")),
      body: ListView(
        children: [
          _buildHrSettings(bleService),
          const Divider(),
          SwitchListTile(
            title: const Text("SpO2 Monitoring (not working)"),
            subtitle: const Text("Automatically measures SpO2 periodically."),
            value: bleService.spo2AutoEnabled,
            onChanged: (bool value) {
              bleService.setAutoSpo2(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Stress Monitoring"),
            subtitle: const Text("Starts periodic stress measurement."),
            value: bleService.stressAutoEnabled,
            onChanged: (bool value) {
              bleService.setAutoStress(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("HRV Monitoring"),
            subtitle: const Text("Enables Scheduled HRV (0x38)."),
            value: bleService.hrvAutoEnabled,
            onChanged: (bool value) {
              bleService.setAutoHrv(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHrSettings(BleService bleService) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text("Heart Rate Monitoring"),
          subtitle: const Text("Enable automatic periodic measurement."),
          value: bleService.hrAutoEnabled,
          onChanged: (bool value) {
            bleService.setAutoHrInterval(value ? bleService.hrInterval : 0);
          },
        ),
        if (bleService.hrAutoEnabled)
          ListTile(
            title: const Text("Measurement Interval"),
            subtitle: Text("Measure every ${bleService.hrInterval} minutes"),
            trailing: DropdownButton<int>(
              value: bleService.hrInterval,
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
          ),
      ],
    );
  }
}
