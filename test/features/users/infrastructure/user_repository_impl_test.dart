import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/users/domain/commands/create_user_command.dart';
import 'package:parking_management/features/users/domain/commands/update_user_command.dart';
import 'package:parking_management/features/users/infrastructure/user_remote_data_source.dart';
import 'package:parking_management/features/users/infrastructure/user_repository_impl.dart';

const _user = User(
  id: 3,
  username: 'op',
  displayName: 'Op',
  role: UserRole.operator,
);

class _FakeRemote implements UserRemoteDataSource {
  Map<String, dynamic>? createdPayload;
  Map<String, dynamic>? updatedPayload;
  int? updatedId;
  Failure? error;

  @override
  Future<List<User>> list() async =>
      error == null ? const [_user] : throw error!;

  @override
  Future<User> create(Map<String, dynamic> payload) async {
    createdPayload = payload;
    return _user;
  }

  @override
  Future<User> update(int id, Map<String, dynamic> payload) async {
    updatedId = id;
    updatedPayload = payload;
    return _user;
  }
}

void main() {
  late _FakeRemote remote;
  late UserRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemote();
    repository = UserRepositoryImpl(remote);
  });

  test('Success: create maps the command to the snake_case payload', () async {
    await repository.create(
      const CreateUserCommand(
        username: 'op',
        displayName: 'Op',
        role: UserRole.admin,
        pin: '1234',
      ),
    );

    expect(remote.createdPayload, {
      'username': 'op',
      'display_name': 'Op',
      'role': 'admin',
      'pin': '1234',
    });
  });

  test('Failure: remote failures propagate unchanged', () async {
    remote.error = const NetworkFailure();

    expect(repository.list, throwsA(const NetworkFailure()));
  });

  test('Security: update sends only the fields that changed', () async {
    await repository.update(const UpdateUserCommand(id: 3, isActive: false));

    expect(remote.updatedId, 3);
    expect(remote.updatedPayload, {'is_active': false});
  });
}
