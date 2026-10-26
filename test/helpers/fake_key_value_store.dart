import 'package:parking_management/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] for cubit tests.
class FakeKeyValueStore implements KeyValueStore {
  final Map<String, Object?> values = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> put(String box, String key, Object? value) async {
    values['$box/$key'] = value;
  }

  @override
  Object? get(String box, String key) => values['$box/$key'];

  @override
  Future<void> remove(String box, String key) async {
    values.remove('$box/$key');
  }
}
