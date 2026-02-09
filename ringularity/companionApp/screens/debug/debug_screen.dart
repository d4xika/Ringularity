import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import 'command_tester_screen.dart';
import 'api_log_screen.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Developer Tools")),
      body: Consumer<BleService>(
        builder: (context, ble, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Device Control",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ElevatedButton.icon(
                onPressed: () => ble.forceStopEverything(),
                icon: const Icon(Icons.power_settings_new),
                label: const Text("FORCE STOP (Kill Lights)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => ble.rebootRing(),
                icon: const Icon(Icons.restart_alt),
                label: const Text("REBOOT RING"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text("Protocol Testing",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CommandTesterScreen()),
                  );
                },
                icon: const Icon(Icons.terminal),
                label: const Text("Open Command Tester / Hex Log"),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ApiLogScreen()),
                  );
                },
                icon: const Icon(Icons.cloud_sync),
                label: const Text("Open Server Logs"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 1, 0, 87),
                    foregroundColor: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text("Live Log (Last Packet)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black12,
                child: Text(
                  ble.lastLog,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Connection Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                title: const Text("Status"),
                subtitle: Text(ble.isConnected ? "Connected" : ble.status),
                trailing: Icon(
                  ble.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: ble.isConnected ? Colors.green : Colors.grey,
                ),
              ),
              if (ble.isConnected)
                ListTile(
                  title: const Text("Device ID"),
                  subtitle: Text(ble.currentDeviceId ?? "Unknown"),
                ),
            ],
          );
        },
      ),
    );
  }
}
