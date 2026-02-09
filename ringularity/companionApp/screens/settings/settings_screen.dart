import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import 'auto_monitoring_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch latest settings from ring on open to ensure UI matches device state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BleService>(context, listen: false).readAutoSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes
    final bleService = Provider.of<BleService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              bleService.readAutoSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reading Ring Settings...")));
            },
          )
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Automatic Monitoring"),
            subtitle: const Text("Configure periodic HR, SpO2, Stress, etc."),
            leading: const Icon(Icons.timer),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to detailed auto-monitoring configuration
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AutoMonitoringScreen()),
              );
            },
          ),
          const Divider(),
          // Other Settings
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Device Management",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          ListTile(
            title: const Text("Pair Ring"),
            subtitle: const Text(
                "Sends Config & Bind commands to mirror original app pairing."),
            leading: const Icon(Icons.link),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Starting Pairing Sequence...")),
              );
              await bleService.startPairing();
            },
          ),
          ListTile(
            title: const Text("Unpair Ring"),
            subtitle: const Text("Removes system bonding (forget device)."),
            leading: const Icon(Icons.link_off),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Removing Bond...")),
              );
              await bleService.unpairRing();
            },
          ),
          ListTile(
            title: const Text("Factory Reset"),
            subtitle: const Text("Resets ring to factory defaults (FF 66 66)."),
            leading: const Icon(Icons.restore),
            onTap: () async {
              // Critical Action: Requires confirmation dialog to prevent accidental wipes.
              bool confirm = await showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                              title: const Text("Confirm Reset"),
                              content: const Text(
                                  "This will reboot the ring and wipe settings. Continue?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text("Reset")),
                              ])) ??
                  false;

              if (confirm) {
                await bleService.factoryReset();
              }
            },
          ),
          ListTile(
            title: const Text("Reboot Ring"),
            subtitle:
                const Text("Restarts the ring (0x08). Fixes stuck sensors."),
            leading: const Icon(Icons.restart_alt),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Rebooting Ring...")));
              await bleService.rebootRing();
            },
          ),
          ListTile(
            title: const Text("Find Ring"),
            subtitle: const Text("Flash the ring."),
            leading: const Icon(Icons.vibration),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sending Find command...")));
              await bleService.findDevice();
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Note: Altering these settings sends commands directly to the ring. "
              "Changes might not persist after ring reboot.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
