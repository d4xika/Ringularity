import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class ManualSpo2Screen extends StatelessWidget {
  const ManualSpo2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual SpO2")),
      body: Center(
        child: Consumer<BleService>(
          builder: (context, ble, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  "${ble.spo2} %",
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
                      if (ble.isMeasuringSpo2) {
                        ble.stopSpo2();
                      } else {
                        ble.startSpo2();
                      }
                    },
                    icon: Icon(
                        ble.isMeasuringSpo2 ? Icons.stop : Icons.play_arrow),
                    label: Text(ble.isMeasuringSpo2 ? "Stop" : "Start"),
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
