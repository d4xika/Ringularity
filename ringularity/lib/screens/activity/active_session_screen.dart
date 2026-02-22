import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo show ActivityType;
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:provider/provider.dart';
import 'package:ringularity/services/health/activity_service.dart';
import 'package:ringularity/theme/text_styles.dart';

import '../../models/activity_model.dart';
import '../../services/ble/ble_service.dart';
import '../../services/daily_summary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/activity/gps_sheet.dart';
import '../../widgets/common/big_button.dart';

/// A screen that manages and displays a live activity session.
///
/// This screen handles the session timer, connects to the [BleService] to record
/// live metrics (like heart rate and steps), and optionally uses [Geolocator]
/// to track the user's route via GPS in the background.
class ActiveSessionScreen extends StatefulWidget {
  /// The specific category of the activity being tracked.
  final ActivityType type;

  /// Determines whether the session should track the user's location via GPS.
  final bool useGps;

  /// An optional custom title, primarily used for [ActivityType.individual].
  final String? customTitle;

  /// Creates a new [ActiveSessionScreen] instance.
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

  int _baselineActivitySteps = -1;
  int _baselineDailySteps = -1;

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

  /// Initiates the activity session, sets baselines, and starts sensors.
  void _startSession() {
    final service = Provider.of<BleService>(context, listen: false);

    setState(() {
      _isActive = true;
      _isPaused = false;
      _baselineActivitySteps = -1;
      _baselineDailySteps = -1;
    });

    service.startActivity(widget.type);

    _startTimer();

    if (widget.useGps) {
      _initLocationTracking();
    }
  }

  /// Starts the periodic timer to track duration and collect HR data points.
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
              "Real HR point for chart: $currentHr bpm | Collected points: ${_sessionHrData.length}",
            );
          }
        }

        if (_seconds % 3 == 0) {
          service.startHeartRate();
        }
      }
    });
  }

  /// Pauses the active session and halts GPS location updates.
  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    _positionStream?.pause();
  }

  /// Resumes the paused session and continues GPS location updates.
  void _resumeSession() {
    setState(() {
      _isPaused = false;
    });
    _positionStream?.resume();
  }

  /// Configures and starts the background GPS tracking stream.
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

    try {
      debugPrint("GPS wake-up call startet...");

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );

      await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      debugPrint("GPS wake-up call successfull!");
    } catch (e) {
      debugPrint("GPS wake-up call timeout (normal with poor reception): $e");
    }

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Your route is being recorded in the background.",
          notificationTitle: "Active Session",
          enableWakeLock: true,
          notificationIcon: AndroidResource(
            name: 'ic_notification',
            defType: 'drawable',
          ),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: geo.ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          debugPrint(
            "Got GPS point: Lat ${position.latitude}, Lng ${position.longitude}",
          );

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
        });
  }

  /// Stops the session, compiles the [ActivityModel], and saves it to the backend/local storage.
  void _finishSession() {
    _timer?.cancel();
    _positionStream?.cancel();
    final service = Provider.of<BleService>(context, listen: false);

    service.stopActivity();

    final int currentSteps = service.steps;
    int sessionSteps = 0;

    if (service.activitySteps > 0 && _baselineActivitySteps != -1) {
      sessionSteps = service.activitySteps - _baselineActivitySteps;
    } else if (_baselineDailySteps != -1) {
      sessionSteps = currentSteps - _baselineDailySteps;
    }
    if (sessionSteps < 0) sessionSteps = 0;

    double finalDistKm = 0.0;

    if (widget.useGps) {
      finalDistKm = _gpsDistanceKm;
    } else {
      finalDistKm = (sessionSteps * 0.762) / 1000.0;
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

    final int newTotalDailySteps =
        (_baselineDailySteps != -1 ? _baselineDailySteps : service.steps) +
        sessionSteps;

    summaryService.saveOrUpdateDay(
      date: today,
      steps: newTotalDailySteps,
      sleepHours: service.totalSleepMinutes / 60.0,
      activityMinutes: todayActivityMins,
      goalSteps: service.goalSteps,
      goalSleep: service.goalSleep,
      goalActivity: service.goalActivity,
    );

    service.triggerSmartSync(force: true);

    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 2);
  }

  /// Formats the elapsed session duration into a `HH:mm:ss` string.
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
    if (_isActive) {
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
        String displayDistance = "0.00";

        if (_isActive) {
          if (service.activitySteps > 0) {
            if (_baselineActivitySteps == -1) {
              _baselineActivitySteps = service.activitySteps;
            }
            sessionSteps = service.activitySteps - _baselineActivitySteps;
          } else {
            if (_baselineDailySteps == -1) {
              _baselineDailySteps = service.steps;
            }
            sessionSteps = service.steps - _baselineDailySteps;
          }

          if (sessionSteps < 0) sessionSteps = 0;

          if (widget.useGps) {
            displayDistance = _gpsDistanceKm.toStringAsFixed(2);
          } else {
            final double distKm = (sessionSteps * 0.762) / 1000.0;
            displayDistance = distKm.toStringAsFixed(2);
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
                    _buildStatItem(displayDistance, "km"),
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

  /// Builds the play/pause and finish controls based on the current session state.
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

  /// Builds a vertical text column for displaying a specific live metric.
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.subtitle.copyWith(fontSize: 24)),
        Text(label, style: AppTextStyles.bodygrey),
      ],
    );
  }
}
