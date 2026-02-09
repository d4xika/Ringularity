import 'package:flutter/material.dart';
import 'screens/auth/start_screen.dart';

import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BleService()..init(),
          lazy: false,
        ),
      ],
      child: const SmartRingApp(),
    ),
  );
}

//TODO: set logo for app

//TODO: check if it runs for IOS

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
