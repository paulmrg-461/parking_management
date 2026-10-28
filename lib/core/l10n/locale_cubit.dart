import 'dart:ui';

import '../state/resilient_cubit.dart';
import '../storage/key_value_store.dart';

/// Device language preference: `null` follows the system locale; otherwise an
/// explicit `es`/`en`. Stored locally (not per site).
class LocaleCubit extends ResilientCubit<Locale?> {
  LocaleCubit(this._store) : super(null);

  static const _box = 'preferences';
  static const _key = 'locale';

  final KeyValueStore _store;

  void restore() {
    final stored = _store.get(_box, _key);
    if (stored is! String) {
      return;
    }
    emit(switch (stored) {
      'es' => const Locale('es'),
      'en' => const Locale('en'),
      _ => null,
    });
  }

  Future<void> select(Locale? locale) async {
    emit(locale);
    try {
      await _store.put(_box, _key, locale?.languageCode ?? 'system');
    } catch (_) {
      // A failed write keeps the in-memory choice for this session.
    }
  }
}
