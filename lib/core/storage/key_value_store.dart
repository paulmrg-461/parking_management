abstract class KeyValueStore {
  Future<void> init();

  Future<void> close();

  Future<void> put(String box, String key, Object? value);

  Object? get(String box, String key);

  Future<void> remove(String box, String key);
}
