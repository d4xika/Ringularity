import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class ManualStressScreen extends StatelessWidget {
  const ManualStressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual Stress")),
      body: Center(
        child: Consumer<BleService>(
          builder: (context, ble, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.psychology, size: 100, color: Colors.purple),
                const SizedBox(height: 20),
                Text(
                  "${ble.stress}",
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const Text("Stress Score",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                if (!ble.isConnected)
                  const Text("Ring Disconnected",
                      style: TextStyle(color: Colors.red))
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      if (ble.isMeasuringStress) {
                        ble.stopStressTest();
                      } else {
                        ble.startStressTest();
                      }
                    },
                    icon: Icon(
                        ble.isMeasuringStress ? Icons.stop : Icons.play_arrow),
                    label: Text(ble.isMeasuringStress ? "Stop" : "Start"),
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
