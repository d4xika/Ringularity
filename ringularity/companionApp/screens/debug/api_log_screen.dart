import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import 'package:flutter_application_1/services/api/api_service.dart';

class ApiLogScreen extends StatelessWidget {
  const ApiLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access ApiService through BleService
    final bleService = Provider.of<BleService>(context, listen: false);

    return ChangeNotifierProvider.value(
      value: bleService.apiService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("API Logs (Server)"),
          actions: [
            Consumer<ApiService>(
              builder: (context, api, _) => IconButton(
                icon: const Icon(Icons.delete),
                onPressed: api.clearLogs,
                tooltip: "Clear Logs",
              ),
            ),
          ],
        ),
        body: Consumer<ApiService>(
          builder: (context, api, child) {
            if (api.logs.isEmpty) {
              return const Center(
                child: Text("No logs yet.\nTry syncing data.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              );
            }
            return ListView.builder(
              itemCount: api.logs.length,
              itemBuilder: (context, index) {
                final log = api.logs[index];
                Color color = Colors.black;
                if (log.contains("SUCCESS")) color = Colors.green;
                if (log.contains("FAIL") || log.contains("ERROR"))
                  color = Colors.red;
                if (log.contains("SYNC")) color = Colors.blue;

                return InkWell(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: log));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Log copied!")));
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      log,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 12, color: color),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
