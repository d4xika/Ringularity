import 'package:flutter/material.dart';
import 'manual_hr_screen.dart';
import 'manual_spo2_screen.dart';
import 'manual_stress_screen.dart';
import 'manual_hrv_screen.dart';
import 'raw_sensor_screen.dart';

class MeasurementMenuScreen extends StatelessWidget {
  const MeasurementMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Measure")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuTile(
            context,
            "Heart Rate",
            "Manual HR Measurement",
            Icons.favorite,
            Colors.red,
            const ManualHrScreen(),
          ),
          const SizedBox(height: 10),
          _buildMenuTile(
            context,
            "SpO2",
            "Manual SpO2 Measurement",
            Icons.water_drop,
            Colors.blue,
            const ManualSpo2Screen(),
          ),
          const SizedBox(height: 10),
          _buildMenuTile(
            context,
            "Stress",
            "Manual Stress Measurement",
            Icons.psychology,
            Colors.purple,
            const ManualStressScreen(),
          ),
          const SizedBox(height: 10),
          _buildMenuTile(
            context,
            "HRV",
            "Manual HRV Measurement",
            Icons.monitor_heart,
            Colors.deepPurple,
            const ManualHrvScreen(),
          ),
          const Divider(height: 40),
          _buildMenuTile(
            context,
            "Raw Sensor Stream",
            "Live Accelerometer & PPG",
            Icons.sensors,
            Colors.orange,
            const RawSensorScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, String subtitle,
      IconData icon, Color color, Widget page) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }
}
