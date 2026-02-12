import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/big_button.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ActivityType type;
  final bool useGps;
  final String? customTitle; // Neu: Optionaler Titel

  const ActiveSessionScreen({
    super.key,
    required this.type,
    required this.useGps,
    this.customTitle,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _isActive = false;
  bool _isPaused = false;

  // Mock Werte
  double _distance = 0.0;
  int _steps = 0;
  final int _bpm = 85;

  @override
  void initState() {
    super.initState();
  }

  void _startSession() {
    setState(() {
      _isActive = true;
      _isPaused = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isActive) {
        setState(() {
          _seconds++;
          _distance += 0.002;
          _steps += 2;
        });
      }
    });
  }

  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
  }

  void _finishSession() {
    _timer?.cancel();

    final result = ActivityModel(
      type: widget.type,
      customTitle: widget.customTitle,
      date: DateTime.now(),
      duration: Duration(seconds: _seconds),
      distanceKm: _distance,
      avgHeartRate: _bpm,
      steps: _steps,
    );

    Navigator.pop(context);
    Navigator.pop(context, result);
  }

  String get _formattedTime {
    final duration = Duration(seconds: _seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        widget.customTitle ??
        widget.type.toString().split('.').last.toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/starry_night_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title.toUpperCase()),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              "$_steps",
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const Text("Steps", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            Text(
              _formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),

            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem("$_bpm", "bpm"),
                _buildStatItem(_distance.toStringAsFixed(2), "Km"),
              ],
            ),
            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: _buildControls(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!_isActive) {
      return BigButton(
        backgroundColor: AppColors.mainColor,
        onPressed: _startSession,
        child: const Text(
          "START ACTIVITY",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          backgroundColor: AppColors.mainColor,
          onPressed: _isPaused ? _resumeSession : _pauseSession,
          child: Icon(
            _isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.black,
          ),
        ),

        if (_isPaused) ...[
          const SizedBox(width: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _finishSession,
            child: const Text("Finish", style: TextStyle(color: Colors.white)),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
