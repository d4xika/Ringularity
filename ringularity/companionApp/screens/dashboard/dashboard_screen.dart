import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import '../measurements/manual_hr_screen.dart';
import '../measurements/manual_spo2_screen.dart';
import '../measurements/manual_stress_screen.dart';
import '../measurements/manual_hrv_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ringularity V0.0.5 Dashboard')),
      // Consumer<BleService> rebuilds this widget tree whenever BleService calls notifyListeners()
      body: Consumer<BleService>(
        builder: (context, ble, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Connection Header
                // Displays current connection status and allows connecting/disconnecting
                Card(
                  color: ble.isConnected ? Colors.green[100] : Colors.red[100],
                  child: ListTile(
                    leading: Icon(
                        ble.isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: ble.isConnected
                            ? Colors.green[800]
                            : Colors.red[800]),
                    title: Text(ble.isConnected ? "Connected" : "Disconnected"),
                    subtitle: Text(ble.isConnected
                        ? "Battery: ${ble.batteryLevel}%"
                        : ble.status),
                    trailing: ble.isConnected
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: ble.getBatteryLevel)
                        : ElevatedButton(
                            onPressed: ble.isScanning ? null : ble.startScan,
                            child: Text(
                                ble.isScanning ? "Scanning..." : "Connect"),
                          ),
                  ),
                ),

                // Paired Devices
                // Shows a list of previously paired devices for quick reconnection
                if (!ble.isConnected && ble.bondedDevices.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Paired Devices:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    height: 120, // Smaller height for paired
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                        itemCount: ble.bondedDevices.length,
                        itemBuilder: (ctx, i) {
                          final d = ble.bondedDevices[i];
                          return ListTile(
                            leading: const Icon(Icons.link, color: Colors.blue),
                            title: Text(d.platformName.isNotEmpty
                                ? d.platformName
                                : "Unknown Device"),
                            subtitle: Text(d.remoteId.toString()),
                            onTap: () => ble.connectToDevice(d),
                          );
                        }),
                  ),
                  const SizedBox(height: 10),
                ],

                // Scan Results (if not connected)
                // Shows available devices turned up by the scanner
                if (!ble.isConnected && ble.scanResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Devices Found:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                        itemCount: ble.scanResults.length,
                        itemBuilder: (ctx, i) {
                          final r = ble.scanResults[i];
                          String name = r.device.platformName.isNotEmpty
                              ? r.device.platformName
                              : r.advertisementData.advName;
                          if (name.isEmpty) name = "Unknown";
                          return ListTile(
                            title: Text(name),
                            subtitle: Text(r.device.remoteId.toString()),
                            onTap: () => ble.connectToDevice(r.device),
                          );
                        }),
                  )
                ],

                const SizedBox(height: 20),

                // 2. Metrics Grid
                // Displays the latest sensor readings (HR, SpO2, Stress, etc.) in a grid
                if (ble.isConnected) ...[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      _MetricCard(
                        title: "Heart Rate",
                        value: "${ble.heartRate}",
                        unit: "BPM",
                        icon: Icons.favorite,
                        color: Colors.red,
                        time: ble.heartRateTime,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ManualHrScreen()),
                        ),
                      ),
                      _MetricCard(
                        title: "SpO2",
                        value: "${ble.spo2}",
                        unit: "%",
                        icon: Icons.water_drop,
                        color: Colors.blue,
                        time: ble.spo2Time,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ManualSpo2Screen()),
                        ),
                      ),
                      _MetricCard(
                        title: "Stress",
                        value: "${ble.stress}",
                        unit: "Score", // 0-100
                        icon: Icons.psychology,
                        color: Colors.purple,
                        time: ble.stressTime,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ManualStressScreen()),
                        ),
                      ),
                      _MetricCard(
                        title: "HRV",
                        value: "${ble.hrv}",
                        unit: "ms",
                        icon: Icons.monitor_heart,
                        color: Colors.deepPurple,
                        time: ble.hrvTime,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ManualHrvScreen()),
                        ),
                      ),
                      _MetricCard(
                        title: "Steps",
                        value: "${ble.steps}",
                        unit: "steps",
                        icon: Icons.directions_walk,
                        color: Colors.orange,
                        time: ble.stepsTime,
                      ),
                      _MetricCard(
                        title: "Sleep",
                        value: ble.totalSleepTimeFormatted,
                        unit: "Duration",
                        icon: Icons.bedtime,
                        color: Colors.indigo,
                        time: "Last Sync", // Or better label?
                        onTap: () {
                          // Optional: Navigate to Sleep details screen if exists
                          // For now, just a snackbar or no-op
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Sleep Details not implemented yet")));
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Main Action Buttons
                  // "Sync All Data" triggers the main synchronization flow
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: ble.isSyncing
                          ? null
                          : () {
                              ble.syncAllData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Syncing all data...")));
                            },
                      icon: ble.isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync),
                      label:
                          Text(ble.isSyncing ? "SYNCING..." : "SYNC ALL DATA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSyncSelectionDialog(context, ble),
                      icon: const Icon(Icons.checklist),
                      label: const Text("SYNC SPECIFIC DATA"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: ble.isSyncing
                          ? null
                          : () =>
                              _showCloudSyncConfirmationDialog(context, ble),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text("SYNC TO CLOUD (10.25.6.11)"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCloudSyncConfirmationDialog(BuildContext context, BleService ble) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Network"),
        content: const Text(
            "Are you sure you are in the correct network to sync to the cloud?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Uploading data to cloud...")));
              await ble.syncToCloud();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Cloud upload finished (check logs)")));
              }
            },
            child: const Text("Sync"),
          ),
        ],
      ),
    );
  }

  void _showSyncSelectionDialog(BuildContext context, BleService ble) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Data to Sync"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_walk, color: Colors.orange),
              title: const Text("Steps"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncStepsHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing Steps...")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: const Text("Heart Rate"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncHeartRateHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing Heart Rate...")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: const Text("SpO2"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncSpo2History();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing SpO2...")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.purple),
              title: const Text("Stress"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncStressHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing Stress...")));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.monitor_heart, color: Colors.deepPurple),
              title: const Text("HRV"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncHrvHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing HRV...")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime, color: Colors.indigo),
              title: const Text("Sleep"),
              onTap: () {
                Navigator.pop(ctx);
                ble.syncSleepHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Syncing Sleep...")));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          )
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String time;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color),
                  Text(time,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text("$title ($unit)",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
