import 'package:flutter/material.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(const SmartRingApp());
}

class SmartRingApp extends StatelessWidget {
  const SmartRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ringularity',
      home: StartScreen(),
    );
  }
}
