import '../storage/key_value_store.dart';
import 'lot_session.dart';

/// Persists the active lot and applies it to [LotSession] (which the
/// composition root wires into the Supabase client header).
class LotContext {
  LotContext(this._store, this.session);

  static const box = 'lot_context';
  static const _key = 'active_lot_id';

  final KeyValueStore _store;
  final LotSession session;

  int? get activeLotId => session.activeLotId;

  /// Reads the last selection persisted on this device (no network).
  int? restore() {
    final value = _store.get(box, _key);
    final id = switch (value) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    if (id != null) {
      session.select(id);
    }
    return id;
  }

  Future<void> select(int? lotId) async {
    session.select(lotId);
    // Remembering the choice is a convenience: a slow or broken local store
    // (seen on web after login) must never block sign-in.
    try {
      await _store.put(box, _key, lotId).timeout(const Duration(seconds: 2));
    } on Object {
      // Keep the in-memory selection for this session.
    }
  }

  void onApplied(void Function(int? lotId) callback) =>
      session.onChanged = callback;
}
