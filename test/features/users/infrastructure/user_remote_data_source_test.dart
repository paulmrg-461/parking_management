import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/users/infrastructure/user_remote_data_source.dart';

import '../../../helpers/fake_http.dart';

const _userJson = {
  'id': 3,
  'username': 'op',
  'display_name': 'Operador',
  'role': 'operator',
  'is_active': true,
};

void main() {
  test('Success: lists users from GET /api/users', () async {
    final adapter = FakeHttpAdapter((_) async => jsonBody([_userJson], 200));
    final source = DioUserRemoteDataSource(dioWith(adapter));

    final users = await source.list();

    expect(adapter.requests.single.path, '/api/users');
    expect(users.single.username, 'op');
    expect(users.single.role, UserRole.operator);
  });

  test(
    'Failure: a 409 on create maps to ValidationFailure with detail',
    () async {
      final adapter = FakeHttpAdapter(
        (_) async => jsonBody({'detail': 'Username already exists'}, 409),
      );
      final source = DioUserRemoteDataSource(dioWith(adapter));

      expect(
        () => source.create({'username': 'op'}),
        throwsA(const ValidationFailure('Username already exists')),
      );
    },
  );

  test(
    'Security: update PATCHes only the given fields to /api/users/{id}',
    () async {
      final adapter = FakeHttpAdapter((_) async => jsonBody(_userJson, 200));
      final source = DioUserRemoteDataSource(dioWith(adapter));

      await source.update(3, {'is_active': false});

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/users/3');
      expect(request.data, {'is_active': false});
      expect(request.headers.containsKey('Authorization'), isFalse);
    },
  );

  test('Failure: connection errors map to NetworkFailure', () async {
    final adapter = FakeHttpAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final source = DioUserRemoteDataSource(dioWith(adapter));

    expect(source.list, throwsA(isA<NetworkFailure>()));
  });
}
