import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../screens/privacy/consent_screen.dart';
import '../../services/user/consent_service.dart';
import '../../services/user/storage_service.dart';

/// Shows onboarding before consent and defers mounting the application services.
///
/// After the first start, withdrawal hides the application without disposing its
/// providers. The consent-aware HTTP transport independently enforces the network
/// restriction while this widget controls visibility and re-entry.
class ConsentGate extends StatefulWidget {
  /// Application subtree mounted after consent and retained during later withdrawals.
  final Widget child;

  /// One-time initialization performed after consent, before the application is mounted.
  final Future<void> Function()? onStart;

  /// Restarts navigation when consent is granted again after the application has started.
  final VoidCallback? onResume;

  /// Creates a consent boundary around the application and its startup callbacks.
  const ConsentGate({
    super.key,
    required this.child,
    this.onStart,
    this.onResume,
  });

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

/// Retains the initialized application while tracking changes to the active consent decision.
class _ConsentGateState extends State<ConsentGate> {
  bool _started = false;
  bool _starting = false;
  late bool _hadConsent;

  @override
  void initState() {
    super.initState();
    _hadConsent = ConsentService.instance.hasConsent;
    ConsentService.instance.addListener(_changed);
    if (_hadConsent) {
      _start();
    }
  }

  /// Runs startup once and mounts the application after initialization completes.
  Future<void> _start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    await widget.onStart?.call();
    if (mounted) {
      setState(() {
        _started = true;
      });
    }
  }

  /// Updates the gate and resets navigation when an already-started app regains consent.
  void _changed() {
    final accepted = ConsentService.instance.hasConsent;
    if (accepted && !_started) {
      _start();
    } else if (accepted && !_hadConsent) {
      widget.onResume?.call();
    }
    _hadConsent = accepted;
    setState(() {});
  }

  @override
  void dispose() {
    ConsentService.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accepted = ConsentService.instance.hasConsent;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_started) Offstage(offstage: !accepted, child: widget.child),
          if (!accepted || !_started)
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.mainColor,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: AppColors.background,
                useMaterial3: true,
              ),
              debugShowCheckedModeBanner: false,
              home: accepted
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : ConsentScreen(
                      key: ValueKey(StorageService.currentSession?.userId),
                    ),
            ),
        ],
      ),
    );
  }
}
