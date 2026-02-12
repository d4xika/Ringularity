import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../services/ble/ble_service.dart';
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

  // Session Start Baselines
  int _startSteps = 0;
  int _startDistance = 0;

  @override
  void initState() {
    super.initState();
  }

  void _startSession() {
    final service = Provider.of<BleService>(context, listen: false);

    // Capture baseline values
    setState(() {
      _isActive = true;
      _isPaused = false;
      _startSteps = service.steps;
      _startDistance = service.distance;
    });

    // Start Activity on Ring
    service.startActivity(widget.type);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isActive) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    // Ideally send pause command if supported, but for now just UI pause
  }

  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
  }

  void _finishSession() {
    _timer?.cancel();
    final service = Provider.of<BleService>(context, listen: false);

    // Stop Activity on Ring
    service.stopActivity();

    // Calculate final totals
    int currentSteps = service.steps;
    int currentDist = service.distance;

    // Handle midnight reset edge case (if current < start)
    int sessionSteps = (currentSteps >= _startSteps)
        ? currentSteps - _startSteps
        : currentSteps;
    double sessionDistKm =
        ((currentDist >= _startDistance)
            ? currentDist - _startDistance
            : currentDist) /
        1000.0;

    final result = ActivityModel(
      type: widget.type,
      customTitle: widget.customTitle,
      date: DateTime.now(),
      duration: Duration(seconds: _seconds),
      distanceKm: sessionDistKm,
      avgHeartRate: service
          .heartRate, // Using final HR as 'avg' for now, could calculate real avg
      steps: sessionSteps,
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
    // Ensure we stop if user just backs out without finishing?
    // Usually 'dispose' happens on pop. If _isActive is true, maybe we should auto-stop?
    if (_isActive) {
      // Defer execution to avoid locking the widget tree during dispose
      Future.microtask(() {
        BleService().stopActivity();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        widget.customTitle ??
        widget.type.toString().split('.').last.toUpperCase();

    return Consumer<BleService>(
      builder: (context, service, child) {
        // Calculate Session Live Values
        int currentSteps = service.steps;
        int currentDist = service.distance; // meters

        int sessionSteps = 0;
        double sessionDistKm = 0.0;

        if (_isActive) {
          sessionSteps = (currentSteps >= _startSteps)
              ? currentSteps - _startSteps
              : currentSteps;

          int distMeters = (currentDist >= _startDistance)
              ? currentDist - _startDistance
              : currentDist;

          sessionDistKm = distMeters / 1000.0;
        }

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
                  "$sessionSteps",
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
                    _buildStatItem("${service.heartRate}", "bpm"),
                    _buildStatItem(sessionDistKm.toStringAsFixed(2), "Km"),
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
      },
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
