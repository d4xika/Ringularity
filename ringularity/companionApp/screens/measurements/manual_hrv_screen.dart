import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class ManualHrvScreen extends StatelessWidget {
  const ManualHrvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual HRV")),
      body: Center(
        child: Consumer<BleService>(
          builder: (context, ble, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monitor_heart,
                    size: 100, color: Colors.deepPurple),
                const SizedBox(height: 20),
                Text(
                  "${ble.hrv} ms",
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
                      if (ble.isMeasuringHrv) {
                        ble.stopRealTimeHrv();
                      } else {
                        ble.startRealTimeHrv();
                      }
                    },
                    icon: Icon(
                        ble.isMeasuringHrv ? Icons.stop : Icons.play_arrow),
                    label: Text(ble.isMeasuringHrv ? "Stop" : "Start"),
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
