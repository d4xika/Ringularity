import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/app_colors.dart';
import 'package:ringularity/theme/text_styles.dart';

class ApiDebugScreen extends StatefulWidget {
  const ApiDebugScreen({super.key});

  @override
  State<ApiDebugScreen> createState() => _ApiDebugScreenState();
}

class _ApiDebugScreenState extends State<ApiDebugScreen> {
  final ApiService _apiService = ApiService();
  final BleService _bleService = BleService();

  DateTime _selectedDate = DateTime.now();
  String _selectedMetric = 'Steps'; // Steps, Heart Rate, Sleep, HRV
  List<dynamic> _dataList = [];
  bool _isLoading = false;

  final List<String> _metrics = ['Steps', 'Heart Rate', 'Sleep', 'HRV'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _dataList = [];
    });

    try {
      List<dynamic> data = [];
      switch (_selectedMetric) {
        case 'Steps':
          data = await _apiService.getSteps(_selectedDate);
          break;
        case 'Heart Rate':
          data = await _apiService.getHeartRate(_selectedDate);
          break;
        case 'Sleep':
          data = await _apiService.getSleep(_selectedDate);
          break;
        case 'HRV':
          data = await _apiService.getHrv(_selectedDate);
          break;
      }

      if (mounted) {
        setState(() {
          _dataList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.mainColor,
              onPrimary: Colors.black,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Debug Console"),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.mainColor,
            labelColor: AppColors.mainColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Data"),
              Tab(text: "API Logs"),
              Tab(text: "BLE Logs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildDataTab(), _buildApiLogsTab(), _buildBleLogsTab()],
        ),
      ),
    );
  }

  Widget _buildDataTab() {
    return Column(
      children: [
        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.cardBackground,
          child: Column(
            children: [
              // Date Selector
              InkWell(
                onTap: () => _selectDate(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Date:", style: AppTextStyles.bodywhite),
                    Row(
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.mainColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Metric Selector
              DropdownButtonFormField<String>(
                value: _selectedMetric,
                dropdownColor: AppColors.cardBackground,
                decoration: const InputDecoration(
                  labelText: "Metric",
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.mainColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                items: _metrics.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMetric = newValue;
                    });
                    _fetchData();
                  }
                },
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.mainColor),
                )
              : _dataList.isEmpty
              ? const Center(
                  child: Text(
                    "No data found for this date.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dataList.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final item = _dataList[index];
                    return _buildDataItem(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildApiLogsTab() {
    return AnimatedBuilder(
      animation: _apiService,
      builder: (context, child) {
        final logs = _apiService.logs;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _apiService.clearLogs(),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text("Clear"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SelectableText(
                      logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBleLogsTab() {
    return AnimatedBuilder(
      animation: _bleService,
      builder: (context, child) {
        final logs = _bleService.protocolLog;

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  // Show newest at the top
                  final log = logs[logs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SelectableText(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: log.contains("TX:")
                            ? Colors.blueAccent
                            : (log.contains("RX:")
                                  ? Colors.greenAccent
                                  : Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataItem(dynamic item) {
    String timeStr = "Unknown Time";
    String valueStr = "Unknown Value";

    try {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('recorded_at')) {
          final date = DateTime.parse(item['recorded_at']).toLocal();
          timeStr = DateFormat('HH:mm:ss').format(date);
        }

        if (_selectedMetric == 'Steps') {
          valueStr = "${item['steps']} steps";
        } else if (_selectedMetric == 'Heart Rate') {
          valueStr = "${item['bpm']} bpm";
        } else if (_selectedMetric == 'Sleep') {
          valueStr = item.toString();
          if (item.containsKey('stage')) valueStr = "Stage: ${item['stage']}";
        } else if (_selectedMetric == 'HRV') {
          valueStr = "${item['hrv_val']} ms";
        }
      } else {
        valueStr = item.toString();
      }
    } catch (e) {
      valueStr = "Error parsing: $item";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(timeStr, style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              valueStr,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
