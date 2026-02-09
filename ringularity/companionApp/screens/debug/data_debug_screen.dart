import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import 'package:flutter_application_1/services/ble/ble_constants.dart';

class DataDebugScreen extends StatelessWidget {
  const DataDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Data Debugger"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Protocol Log"),
              Tab(text: "Steps Raw"),
              Tab(text: "HR Raw"),
              Tab(text: "SpO2 Raw"),
              Tab(text: "Stress Raw"),
              Tab(text: "HRV Raw"),
              Tab(text: "Sleep Raw"),
            ],
          ),
        ),
        body: Consumer<BleService>(
          builder: (context, ble, child) {
            return TabBarView(
              children: [
                _buildProtocolLog(ble, context),
                _buildStepsList(ble),
                _buildHrList(ble),
                _buildSpo2List(ble),
                _buildStressList(ble),
                _buildHrvList(ble),
                _buildSleepList(ble),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepsList(BleService ble) {
    if (ble.stepsHistory.isEmpty) {
      return const Center(child: Text("No steps data"));
    }
    return ListView.builder(
      itemCount: ble.stepsHistory.length,
      itemBuilder: (context, index) {
        final point = ble.stepsHistory[index];
        // Steps x is index (0-96)
        int totalMinutes = point.x.toInt() * 15;
        int h = totalMinutes ~/ 60;
        int m = totalMinutes % 60;
        String timeStr =
            "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

        return ListTile(
          dense: true,
          title: Text("Index: ${point.x} ($timeStr)"),
          trailing: Text("Steps: ${point.y}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildHrList(BleService ble) {
    if (ble.hrHistory.isEmpty) {
      return const Center(child: Text("No HR data"));
    }
    // Sort by time?
    List<dynamic> points = List.from(ble.hrHistory);
    // points is List<Point>

    return ListView.builder(
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        // HR x is minutes from midnight
        int totalMinutes = point.x.toInt();
        int h = totalMinutes ~/ 60;
        int m = totalMinutes % 60;
        String timeStr =
            "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

        return ListTile(
          dense: true,
          title: Text("Time: $timeStr (Min: ${point.x})"),
          trailing: Text("${point.y} BPM",
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildSpo2List(BleService ble) {
    if (ble.spo2History.isEmpty) {
      return const Center(child: Text("No SpO2 data"));
    }
    List<dynamic> points = List.from(ble.spo2History);

    return ListView.builder(
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        // SpO2 x is minutes from midnight
        int totalMinutes = point.x.toInt();
        int h = totalMinutes ~/ 60;
        int m = totalMinutes % 60;
        String timeStr =
            "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

        return ListTile(
          dense: true,
          title: Text("Time: $timeStr (Min: ${point.x})"),
          trailing: Text("${point.y}%",
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildStressList(BleService ble) {
    if (ble.stressHistory.isEmpty) {
      return const Center(child: Text("No Stress data"));
    }
    List<dynamic> points = List.from(ble.stressHistory);

    return ListView.builder(
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        int totalMinutes = point.x.toInt();
        int h = totalMinutes ~/ 60;
        int m = totalMinutes % 60;
        String timeStr =
            "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

        return ListTile(
          dense: true,
          title: Text("Time: $timeStr (Min: ${point.x})"),
          trailing: Text("${point.y}",
              style: const TextStyle(
                  color: Colors.purple, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildHrvList(BleService ble) {
    if (ble.hrvHistory.isEmpty) {
      return const Center(child: Text("No HRV data"));
    }
    List<dynamic> points = List.from(ble.hrvHistory);

    return ListView.builder(
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        int totalMinutes = point.x.toInt();
        int h = totalMinutes ~/ 60;
        int m = totalMinutes % 60;
        String timeStr =
            "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

        return ListTile(
          dense: true,
          title: Text("Time: $timeStr (Min: ${point.x})"),
          trailing: Text("${point.y} ms",
              style: const TextStyle(
                  color: Colors.pink, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildSleepList(BleService ble) {
    if (ble.sleepHistory.isEmpty) {
      return const Center(child: Text("No Sleep data"));
    }
    // ble.sleepHistory is List<SleepData>
    var data = ble.sleepHistory;

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final dt = item.timestamp;
        String timeStr =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

        String stageStr = "Unknown (${item.stage})";
        Color color = Colors.grey;

        if (item.stage == BleConstants.sleepAwake) {
          stageStr = "Awake";
          color = Colors.orange;
        } else if (item.stage == BleConstants.sleepLight) {
          stageStr = "Light";
          color = Colors.blue;
        } else if (item.stage == BleConstants.sleepDeep) {
          stageStr = "Deep";
          color = Colors.indigo;
        }

        return ListTile(
          dense: true,
          title: Text("$timeStr - $stageStr"),
          subtitle: Text("Duration: ${item.durationMinutes} mins"),
          trailing: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  Widget _buildProtocolLog(BleService ble, BuildContext context) {
    if (ble.protocolLog.isEmpty) {
      return const Center(child: Text("No protocol logs yet"));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              final text = ble.protocolLog.join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logs copied to clipboard!")),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy Logs to Clipboard"),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: ble.protocolLog.length,
            itemBuilder: (context, index) {
              final entry = ble.protocolLog[ble.protocolLog.length - 1 - index];
              final isTx = entry.contains("TX:");
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  entry,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isTx ? Colors.blue[800] : Colors.green[800],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
