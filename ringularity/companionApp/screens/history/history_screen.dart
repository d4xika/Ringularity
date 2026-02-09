import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import '../debug/data_debug_screen.dart';
import 'widgets/history_chart_widget.dart';
import 'widgets/sleep_graph.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<BleService>(
            builder: (context, ble, child) {
              final dateStr =
                  "${ble.selectedDate.year}-${ble.selectedDate.month}-${ble.selectedDate.day}";
              return GestureDetector(
                // Date Picker Interaction
                // Allows user to pick a past date to view historical data.
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: ble.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && picked != ble.selectedDate) {
                    ble.setSelectedDate(picked);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("History: $dateStr"),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today, size: 20),
                  ],
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.cloud_download),
              tooltip: "Download Day's Data",
              onPressed: () async {
                final ble = Provider.of<BleService>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Downloading data from cloud...")));
                await ble.downloadFromCloud();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Download finished.")));
              },
            ),
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DataDebugScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Steps'),
              Tab(text: 'Heart Rate'),
              Tab(text: 'SpO2'),
              Tab(text: 'Stress'),
              Tab(text: 'HRV'),
              Tab(text: 'Sleep'),
            ],
          ),
        ),
        // Consumer rebuilds the TabBarView content when new data arrives in BleService/BleDataManager
        body: Consumer<BleService>(
          builder: (context, ble, child) {
            return TabBarView(
              physics:
                  const NeverScrollableScrollPhysics(), // Disable tab swipe to avoid conflict with zoom
              children: [
                // Steps History Tab
                HistoryChartWidget(
                  data: ble.stepsHistory,
                  metricLabel: "Total Steps: ${ble.steps}",
                  unit: "steps",
                  color: Colors.blue,
                  emptyMessage: "No Steps Data",
                  onSync: () => ble.startFullSyncSequence(),
                  accumulateData: true,
                  // Steps uses 0-96 quarters usually, widget handles it.
                ),
                // Heart Rate
                HistoryChartWidget(
                  data: ble.hrHistory,
                  metricLabel: "Heart Rate (BPM)",
                  unit: "bpm",
                  color: Colors.red,
                  emptyMessage: "No HR History Data",
                  onSync: () => ble.syncHeartRateHistory(),
                  minY: 0,
                  maxY: 200,
                ),
                // SpO2
                HistoryChartWidget(
                  data: ble.spo2History,
                  metricLabel: "Blood Oxygen (%)",
                  unit: "%",
                  color: Colors.cyan,
                  emptyMessage: "No SpO2 History Data",
                  onSync: () => ble.syncSpo2History(),
                  minY: 70,
                  maxY: 105,
                ),
                // Stress
                HistoryChartWidget(
                  data: ble.stressHistory,
                  metricLabel: "Stress Level (0-100)",
                  unit: "",
                  color: Colors.purple,
                  emptyMessage: "No Stress History Data",
                  onSync: () => ble.syncStressHistory(),
                  minY: 0,
                  maxY: 100,
                ),
                // HRV
                HistoryChartWidget(
                  data: ble.hrvHistory,
                  metricLabel: "HRV (ms)",
                  unit: "ms",
                  color: Colors.pink,
                  emptyMessage: "No HRV History",
                  onSync: () => ble.syncHrvHistory(),
                  minY: 0,
                  maxY: 200,
                ),
                // Sleep
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Sleep Stages",
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SleepGraph(data: ble.sleepHistory),
                      ),
                    ),
                    if (ble.sleepHistory.isEmpty)
                      ElevatedButton(
                        onPressed: () => ble.syncSleepHistory(),
                        child: const Text("Sync Sleep Data"),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
