import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SmartRingApp());
}

class SmartRingApp extends StatelessWidget {
  const SmartRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Ring App',
      home: const HomeScreen(),
    );
  }
}