import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/services/ble/ble_service.dart';

class RawSensorScreen extends StatefulWidget {
  const RawSensorScreen({super.key});

  @override
  State<RawSensorScreen> createState() => _RawSensorScreenState();
}

class _RawSensorScreenState extends State<RawSensorScreen> {
  // ... (Identical to old SensorScreen state logic, but using Provider properly if needed,
  // actually looking at the old code it instantiated BleService() locally which is WRONG if it's singleton/provider.
  // The old code: `final BleService _ble = BleService();` -> This assumes Singleton factory.
  // It also used `Provider.of<BleService>(context)` in build.
  // I will use Provider to get the instance usually, or the singleton factory is fine if defined.
  // BleService has `factory BleService() => _instance;` so `new BleService()` returns the singleton.

  final BleService _ble = BleService(); // Singleton access
  StreamSubscription? _accelSub;
  StreamSubscription? _ppgSub;

  // Accelerometer Data
  int _accelX = 0;
  int _accelY = 0;
  int _accelZ = 0;

  // PPG/SpO2 Raw Data
  int _ppgRaw = 0;

  bool _isStreaming = false;

  // Gesture State
  double _netGforce = 0.0;
  double _scrollAngle = 0.0;
  String _gestureStatus = "Idle";
  Timer? _gestureResetTimer;

  // Graph Data
  final List<FlSpot> _spotsX = [];
  final List<FlSpot> _spotsY = [];
  final List<FlSpot> _spotsZ = [];
  double _timeCounter = 0;
  final int _maxDataPoints = 100;

  @override
  void initState() {
    super.initState();
  }

  void _startListening() {
    _accelSub = _ble.accelStream.listen((data) {
      if (data.length < 8) return;
      try {
        int idx = 2;

        // Parse 12-bit signed values
        // Data format: [High 8 bits] [Low 4 bits | High 4 bits next] ... tricky packing
        // Actually, the code below assumes:
        // Byte 1: High 8 bits of Y
        // Byte 2: Low 4 bits of Y (in high nibble of byte), High 4 bits of Z (in low nibble)?
        // Wait, the code: ((data[idx] << 4) | (data[idx + 1] & 0xf))
        // This takes full byte `data[idx]`, shifts left 4 (becoming 12 bits effective space, 8 bits data),
        // and adds low 4 bits of `data[idx+1]`.
        // This implies the 12-bit value is split across 1.5 bytes.
        int rawY = ((data[idx] << 4) | (data[idx + 1] & 0xf));
        if (rawY > 2047) rawY -= 4096; // Sign extension for 12-bit

        int rawZ = ((data[idx + 2] << 4) | (data[idx + 3] & 0xf));
        if (rawZ > 2047) rawZ -= 4096;

        int rawX = ((data[idx + 4] << 4) | (data[idx + 5] & 0xf));
        if (rawX > 2047) rawX -= 4096;

        // Gesture Logic
        // Calculate vector magnitude to detect movement intensity
        double normX = rawX.toDouble();
        double normY = rawY.toDouble();
        double normZ = rawZ.toDouble();
        double magnitude = sqrt(normX * normX + normY * normY + normZ * normZ);

        // Normalize against gravity (~512 units = 1G based on observation)
        double gForce = (magnitude / 512.0 - 1.0).abs();

        String status = _gestureStatus;
        double angle = _scrollAngle;

        if (gForce < 0.1) {
          angle = atan2(normY, normX);
        } else if (gForce > 0.5) {
          status = "Tap Detected!";
          _resetGestureLater();
        }

        if (mounted) {
          setState(() {
            _accelX = rawX;
            _accelY = rawY;
            _accelZ = rawZ;
            _netGforce = gForce;
            _scrollAngle = angle;
            _gestureStatus = status;

            // Update Graph
            _timeCounter++;
            _spotsX.add(FlSpot(_timeCounter, rawX.toDouble()));
            _spotsY.add(FlSpot(_timeCounter, rawY.toDouble()));
            _spotsZ.add(FlSpot(_timeCounter, rawZ.toDouble()));

            if (_spotsX.length > _maxDataPoints) {
              _spotsX.removeAt(0);
              _spotsY.removeAt(0);
              _spotsZ.removeAt(0);
            }
          });
        }
      } catch (e) {
        debugPrint("Error parsing accel: $e");
      }
    });

    _ppgSub = _ble.ppgStream.listen((data) {
      if (data.isEmpty) return;
      // 0xA1: Raw Realtime Data
      if (data[0] == 0xA1) {
        if (data.length < 4) return;
        // Parse PPG Value (2 bytes)
        int val = (data[2] << 8) | data[3];
        if (mounted) setState(() => _ppgRaw = val);
      } else if (data[0] == 0x69) {
        // 0x69: Heart Rate Measurement Response (sometimes contains raw data)
        if (data.length >= 8) {
          int val = data[6] | (data[7] << 8);
          if (mounted) setState(() => _ppgRaw = val);
        }
      }
    });
  }

  void _stopListening() {
    _accelSub?.cancel();
    _ppgSub?.cancel();
    _accelSub = null;
    _ppgSub = null;
  }

  void _resetGestureLater() {
    _gestureResetTimer?.cancel();
    _gestureResetTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _gestureStatus = "Idle";
        });
      }
    });
  }

  @override
  void dispose() {
    _stopListening();
    if (_isStreaming) {
      _ble.forceStopEverything();
    }
    _gestureResetTimer?.cancel();
    super.dispose();
  }

  void _toggleStream() {
    setState(() {
      _isStreaming = !_isStreaming;
    });
    if (_isStreaming) {
      _startListening();
      _ble.enableRawData();
    } else {
      _stopListening();
      _ble.disableRawData();
    }
  }

  Widget _buildRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text("$value",
              style: const TextStyle(fontSize: 18, fontFamily: 'Monospace')),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool onFinger = _ppgRaw > 2000;

    return Scaffold(
      appBar: AppBar(title: const Text("Raw Sensor Stream")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "----- USE WITH CAUTION ----- \nYou might need to use the 'Factory Reset' command to stop the flashing (in settings). \n This also deletes all the data on the ring. \nI think this is the command for a recalibration. idk how exaclty this works but if you leave the ring off the finger for 5sec and then put it on for 5sec (maybe repeat a few times) it should stop the flashing",
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _toggleStream,
              icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
              label: Text(_isStreaming ? "Stop Stream" : "Start Stream"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isStreaming ? Colors.redAccent : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("Wear Status",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 5),
                        Icon(onFinger ? Icons.fingerprint : Icons.back_hand,
                            color: onFinger ? Colors.green : Colors.orange,
                            size: 32),
                        const SizedBox(height: 5),
                        Text(onFinger ? "ON FINGER" : "OFF FINGER",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    onFinger ? Colors.green : Colors.orange)),
                        Text("PPG: $_ppgRaw",
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("Rotation",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 5),
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent),
                            shape: BoxShape.circle,
                          ),
                          child: Transform.rotate(
                            angle: _scrollAngle,
                            child: const Icon(Icons.navigation,
                                color: Colors.blueAccent),
                          ),
                        ),
                        Text(
                            "${(_scrollAngle * 180 / pi).toStringAsFixed(0)}°"),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Text(
                _gestureStatus,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            const Divider(),

            // Accel Graph
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(
                      show: true, border: Border.all(color: Colors.grey)),
                  minY: -2048,
                  maxY: 2048,
                  lineBarsData: [
                    LineChartBarData(
                        spots: _spotsX,
                        color: Colors.red,
                        dotData: const FlDotData(show: false),
                        barWidth: 2),
                    LineChartBarData(
                        spots: _spotsY,
                        color: Colors.green,
                        dotData: const FlDotData(show: false),
                        barWidth: 2),
                    LineChartBarData(
                        spots: _spotsZ,
                        color: Colors.blue,
                        dotData: const FlDotData(show: false),
                        barWidth: 2),
                  ],
                ),
              ),
            ),
            const Center(
                child: Text("X (Red), Y (Green), Z (Blue)",
                    style: TextStyle(color: Colors.grey))),

            const SizedBox(height: 20),
            _buildCard("Raw Values", [
              _buildRow("Accel X", _accelX),
              _buildRow("Accel Y", _accelY),
              _buildRow("Accel Z", _accelZ),
              _buildRow("G-Force", (_netGforce * 1000).toInt()),
            ]),
          ],
        ),
      ),
    );
  }
}
