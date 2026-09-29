import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../database/active_session_repository.dart';
import '../settings/app_preferences.dart';

class WorkoutWakeLockMonitor extends StatefulWidget {
  const WorkoutWakeLockMonitor({super.key, required this.child});

  final Widget child;

  @override
  State<WorkoutWakeLockMonitor> createState() => _WorkoutWakeLockMonitorState();
}

class _WorkoutWakeLockMonitorState extends State<WorkoutWakeLockMonitor>
    with WidgetsBindingObserver {
  final _activeRepo = ActiveSessionRepository();
  Timer? _timer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _set(false);
    }
  }

  Future<void> _sync() async {
    try {
      final keepAwake = await AppPreferences.instance.keepAwakeDuringWorkout();
      final active = keepAwake ? await _activeRepo.getActiveSession() : null;
      await _set(active != null);
    } catch (_) {
      await _set(false);
    }
  }

  Future<void> _set(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    try {
      await WakelockPlus.toggle(enable: value);
    } catch (_) {
      // Wakelock failure must never interrupt workout logging.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
