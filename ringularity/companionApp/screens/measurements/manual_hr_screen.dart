import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class ManualHrScreen extends StatelessWidget {
  const ManualHrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual Heart Rate")),
      body: Center(
        child: Consumer<BleService>(
          builder: (context, ble, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 100, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  "${ble.heartRate} BPM",
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                if (!ble.isConnected)
                  const Text("Ring Disconnected",
                      style: TextStyle(color: Colors.red))
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      if (ble.isMeasuringHeartRate) {
                        ble.stopHeartRate();
                      } else {
                        ble.startHeartRate();
                      }
                    },
                    icon: Icon(ble.isMeasuringHeartRate
                        ? Icons.stop
                        : Icons.play_arrow),
                    label: Text(ble.isMeasuringHeartRate ? "Stop" : "Start"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
