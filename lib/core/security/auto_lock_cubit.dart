import 'dart:async';

import '../state/resilient_cubit.dart';
import '../storage/key_value_store.dart';

/// Device-level idle lock: after [minutes] without pointer activity the app
/// hides behind the PIN screen. `0` disables it. Persisted per device, not per
/// site (a shared cabin keeps the same policy when switching lots).
class AutoLockCubit extends ResilientCubit<bool> {
  AutoLockCubit(
    this._store, {
    DateTime Function()? clock,
    int defaultMinutes = 5,
  }) : _clock = clock ?? DateTime.now,
       _minutes = defaultMinutes,
       _lastActivity = (clock ?? DateTime.now)(),
       super(false);

  static const _box = 'preferences';
  static const _key = 'auto_lock_minutes';
  static const options = <int>[0, 1, 5, 15, 30];

  final KeyValueStore _store;
  final DateTime Function() _clock;
  DateTime _lastActivity;

  int _minutes;

  int get minutes => _minutes;
  Duration get timeout => Duration(minutes: _minutes);
  bool get enabled => _minutes > 0;

  /// Reads the stored preference; an invalid value keeps the default.
  void restore() {
    final stored = _store.get(_box, _key);
    final value = stored is int ? stored : int.tryParse('${stored ?? ''}');
    if (value != null && (value == 0 || (value >= 1 && value <= 120))) {
      _minutes = value;
    }
    _lastActivity = _clock();
  }

  Future<void> select(int minutes) async {
    _minutes = minutes;
    _lastActivity = _clock();
    if (_minutes == 0) {
      emit(false);
    }
    try {
      await _store.put(_box, _key, minutes);
    } catch (_) {
      // A preference is not worth an error dialog.
    }
  }

  /// Called for every pointer/keyboard interaction while unlocked.
  void recordActivity() {
    _lastActivity = _clock();
  }

  /// Called by the gate timer and when the app resumes.
  void check() {
    if (!enabled || state) {
      return;
    }
    if (_clock().difference(_lastActivity) >= timeout) {
      emit(true);
    }
  }

  void lockNow() {
    if (enabled) {
      emit(true);
    }
  }

  /// Successful PIN check (or sign-out) returns the app to the operator.
  void unlock() {
    _lastActivity = _clock();
    if (state) {
      emit(false);
    }
  }
}
