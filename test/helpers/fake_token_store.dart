import 'package:parking_management/core/storage/token_store.dart';

class FakeTokenStore implements TokenStore {
  FakeTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> delete() async => token = null;
}
