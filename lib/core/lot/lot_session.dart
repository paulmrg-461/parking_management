/// Holds the lot the app is currently working in and keeps the Supabase client
/// header in sync. The database validates membership on every request, so this
/// is only a selector: a wrong value fails with `LotRequiredError`.
class LotSession {
  int? _activeLotId;
  void Function(int? lotId)? onChanged;

  int? get activeLotId => _activeLotId;

  void select(int? lotId) {
    if (_activeLotId == lotId) {
      return;
    }
    _activeLotId = lotId;
    onChanged?.call(lotId);
  }
}
