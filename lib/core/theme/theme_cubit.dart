import 'package:flutter/material.dart';

import '../state/resilient_cubit.dart';
import '../storage/key_value_store.dart';

/// Device-level appearance preference (`system` by default). It is not synced
/// per user: a shared kiosk at night can stay dark across operators.
class ThemeCubit extends ResilientCubit<ThemeMode> {
  ThemeCubit(this._store) : super(ThemeMode.system);

  static const _box = 'preferences';
  static const _key = 'theme_mode';

  final KeyValueStore _store;

  /// Reads the stored choice; a missing or unknown value keeps the system
  /// default.
  void restore() {
    final stored = _store.get(_box, _key);
    if (stored is! String) {
      return;
    }
    emit(switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    });
  }

  Future<void> select(ThemeMode mode) async {
    emit(mode);
    try {
      await _store.put(_box, _key, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // A preference is not worth an error dialog.
    }
  }
}
