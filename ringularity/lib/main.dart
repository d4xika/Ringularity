import 'package:flutter/material.dart';
import '../screens/animated_splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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

class SmartRingApp extends StatelessWidget {
  const SmartRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          Theme.of(context).textTheme,
        ).apply(),
      ),
      debugShowCheckedModeBanner: false,
      title: 'Ringularity',
      home: const AnimatedSplashScreen(),
    );
  }
}
