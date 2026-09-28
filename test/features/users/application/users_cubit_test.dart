import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/users/application/users_cubit.dart';
import 'package:parking_management/features/users/domain/commands/create_user_command.dart';
import 'package:parking_management/features/users/domain/commands/update_user_command.dart';
import 'package:parking_management/features/users/domain/repositories/user_repository.dart';

const _ana = User(
  id: 1,
  username: 'ana',
  displayName: 'Ana',
  role: UserRole.admin,
);
const _op = User(
  id: 2,
  username: 'op',
  displayName: 'Op',
  role: UserRole.operator,
);

class _FakeUserRepository implements UserRepository {
  List<User> users = [_ana];
  Failure? listError;
  Failure? writeError;
  UpdateUserCommand? lastUpdate;

  @override
  Future<List<User>> list() async =>
      listError == null ? List.of(users) : throw listError!;

  @override
  Future<User> create(CreateUserCommand command) async {
    if (writeError != null) {
      throw writeError!;
    }
    users.add(_op);
    return _op;
  }

  @override
  Future<User> update(UpdateUserCommand command) async {
    if (writeError != null) {
      throw writeError!;
    }
    lastUpdate = command;
    return _ana;
  }
}

const _command = CreateUserCommand(
  username: 'op',
  displayName: 'Op',
  role: UserRole.operator,
  pin: '1234',
);

void main() {
  late _FakeUserRepository repository;
  late UsersCubit cubit;

  setUp(() {
    repository = _FakeUserRepository();
    cubit = UsersCubit(repository);
  });

  tearDown(() => cubit.close());

  test(
    'Success: create reloads and ends Loaded with Idle submission',
    () async {
      await cubit.load();
      await cubit.create(_command);

      expect(cubit.state, const UsersLoaded([_ana, _op]));
    },
  );

  test(
    'Failure: a failed create keeps the list and reports SubmissionFailed',
    () async {
      await cubit.load();
      repository.writeError = const ValidationFailure(
        'Username already exists',
      );

      await cubit.create(_command);

      expect(
        cubit.state,
        const UsersLoaded([
          _ana,
        ], submission: SubmissionFailed('Username already exists')),
      );
    },
  );

  test('Failure: a failed initial load is a UsersFailure', () async {
    repository.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, const UsersFailure('offline'));
  });

  test('Security: users without a server id are never updated', () async {
    await cubit.load();

    await cubit.toggleActive(
      const User(username: 'x', displayName: 'X', role: UserRole.admin),
    );

    expect(repository.lastUpdate, isNull);
    expect(cubit.state, const UsersLoaded([_ana]));
  });

  test('Success: toggleActive flips is_active for the user', () async {
    await cubit.load();

    await cubit.toggleActive(_ana);

    expect(repository.lastUpdate?.isActive, isFalse);
    expect(repository.lastUpdate?.id, 1);
  });
}
