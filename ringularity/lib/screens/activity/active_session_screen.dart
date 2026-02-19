import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo show ActivityType;
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:provider/provider.dart';
import 'package:ringularity/services/activity_service.dart';
import 'package:ringularity/theme/text_styles.dart';

import '../../models/activity_model.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/activity/gps_sheet.dart';
import '../../widgets/common/big_button.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ActivityType type;
  final bool useGps;
  final String? customTitle;

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

  StreamSubscription<Position>? _positionStream;
  final List<Position> _route = [];
  double _gpsDistanceKm = 0.0;

  final List<int> _sessionHrData = [];

  int _seconds = 0;
  bool _isActive = false;
  bool _isPaused = false;

  // Session Start Baselines
  int _startSteps = 0;
  int _startDistance = 0;

  @override
  void initState() {
    super.initState();
    if (widget.useGps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => GpsSheet(
            title: "GPS Tracking",
            message: "Please bring your phone with you and turn on GPS!",
            positiveLabel: "OK",
            onPositivePressed: () => Navigator.pop(context),
          ),
        );
      });
    }
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

    if (widget.useGps) {
      _initLocationTracking();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isActive && mounted) {
        setState(() {
          _seconds++;
        });

        final service = Provider.of<BleService>(context, listen: false);

        if (_seconds % 5 == 0) {
          final currentHr = service.heartRate;

          if (currentHr > 30 && currentHr < 220 && currentHr != 105) {
            _sessionHrData.add(currentHr);
            debugPrint(
              "✅ Echter HR PUNKT fürs Chart: $currentHr bpm | Gesammelte Punkte: ${_sessionHrData.length}",
            );
          }
        }

        if (_seconds % 3 == 0) {
          service.startHeartRate();
        }
      }
    });
  }

  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    _positionStream?.pause();
  }

  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
    _positionStream?.resume();
  }

  Future<void> _initLocationTracking() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS Service is disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Your route is being recorded in the background...",
          notificationTitle: "Active Session",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: geo.ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (_isPaused) return;

            setState(() {
              if (_route.isNotEmpty) {
                final lastPoint = _route.last;
                final double distanceMeters = Geolocator.distanceBetween(
                  lastPoint.latitude,
                  lastPoint.longitude,
                  position.latitude,
                  position.longitude,
                );
                _gpsDistanceKm += (distanceMeters / 1000);
              }

              _route.add(position);
            });
          },
        );
  }

  void _finishSession() {
    _timer?.cancel();
    _positionStream?.cancel();
    final service = Provider.of<BleService>(context, listen: false);

    service.stopActivity();

    final int currentSteps = service.steps;
    int sessionSteps = 0;

    if (service.activitySteps > 0) {
      sessionSteps = (service.activitySteps >= _startSteps)
          ? service.activitySteps - _startSteps
          : service.activitySteps;
    } else {
      sessionSteps = (currentSteps >= _startSteps)
          ? currentSteps - _startSteps
          : currentSteps;
    }

    double finalDistKm = 0.0;

    if (widget.useGps) {
      finalDistKm = _gpsDistanceKm;
    } else {
      final int currentDist = service.distance;
      final int distMeters = (currentDist >= _startDistance)
          ? currentDist - _startDistance
          : currentDist;
      finalDistKm = distMeters / 1000.0;
    }

    int calculatedAvgHr = 0;
    if (_sessionHrData.isNotEmpty) {
      final int sum = _sessionHrData.reduce((a, b) => a + b);
      calculatedAvgHr = (sum / _sessionHrData.length).round();
    } else {
      calculatedAvgHr = service.heartRate;
    }

    final result = ActivityModel(
      type: widget.type,
      customTitle: widget.customTitle,
      date: DateTime.now(),
      duration: Duration(seconds: _seconds),
      distanceKm: finalDistKm,
      avgHeartRate: calculatedAvgHr,
      steps: sessionSteps,
      route: List.from(_route),
      hrTrace: List.from(_sessionHrData),
    );

    final activityService = Provider.of<ActivityService>(
      context,
      listen: false,
    );
    final summaryService = Provider.of<DailySummaryService>(
      context,
      listen: false,
    );

    activityService.addActivity(result);

    final today = DateTime.now();
    int todayActivityMins = 0;

    for (var act in activityService.activities) {
      if (DateUtils.isSameDay(act.date, today)) {
        todayActivityMins += act.duration.inMinutes;
      }
    }

    summaryService.saveOrUpdateDay(
      date: today,
      steps: service.steps,
      sleepHours: service.totalSleepMinutes / 60.0,
      activityMinutes: todayActivityMins,
      goalSteps: service.goalSteps,
      goalSleep: service.goalSleep,
      goalActivity: service.goalActivity,
    );

    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 2);
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
    _positionStream?.cancel();
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
        int sessionSteps = 0;

        if (_isActive) {
          final int currentSteps = service.steps;
          sessionSteps = (currentSteps >= _startSteps)
              ? currentSteps - _startSteps
              : 0;
        }

        String displayDistance = "0.00";

        if (_isActive) {
          if (widget.useGps) {
            displayDistance = _gpsDistanceKm.toStringAsFixed(2);
          } else {
            final int currentDist = service.distance;
            final int distDiff = (currentDist >= _startDistance)
                ? currentDist - _startDistance
                : 0;
            displayDistance = (distDiff / 1000.0).toStringAsFixed(2);
          }
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
              titleTextStyle: AppTextStyles.title,
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text("$sessionSteps", style: AppTextStyles.subtitle),
                const Text("Steps", style: AppTextStyles.bodygrey),
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
                    _buildStatItem(displayDistance, "Km"),
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
        child: Text(
          "START ACTIVITY",
          style: AppTextStyles.buttonLabel.copyWith(color: Colors.black),
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
          Expanded(
            child: BigButton(
              backgroundColor: AppColors.mainColor,
              onPressed: _finishSession,
              child: Text(
                "Finish",
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.black),
              ),
            ),
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
        Text(label, style: AppTextStyles.bodygrey),
      ],
    );
  }
}
