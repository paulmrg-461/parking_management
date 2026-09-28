import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/app/app.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/core/network/connectivity_cubit.dart';
import 'package:parking_management/core/sync/sync_status_cubit.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/users/application/users_cubit.dart';

import 'fake_auth_repository.dart';
import 'fake_check_out_repository.dart';
import 'fake_user_repository.dart';
import 'fake_sync_outbox.dart';

AuthSession sessionFor(UserRole role) => AuthSession(
  user: User(id: 1, username: 'juan', displayName: 'Juan', role: role),
  token: 'token',
);

/// Pumps the real [ParkingApp] (router + shell) with fakes. Only the admin
/// `UsersCubit` and the home `DashboardCubit` are registered in get_it,
/// enough to exercise a sub-page.
Future<AuthCubit> pumpApp(
  WidgetTester tester, {
  UserRole? role,
  Size size = const Size(400, 800),
  FakeSyncOutbox? outbox,
  ConnectivityCubit? connectivity,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeAuthRepository(
    sessionToRestore: role == null ? null : sessionFor(role),
  );
  await serviceLocator.reset();
  serviceLocator
    ..registerFactory<UsersCubit>(() => UsersCubit(EmptyUserRepository()))
    ..registerFactory<DashboardCubit>(
      () => DashboardCubit(FakeCheckOutRepository()),
    );
  addTearDown(serviceLocator.reset);
  final syncOutbox = outbox ?? FakeSyncOutbox();
  final auth = AuthCubit(repository);
  await auth.restore();
  final syncStatus = SyncStatusCubit(syncOutbox, syncOutbox.remove);
  await syncStatus.load();
  await tester.pumpWidget(
    ParkingApp(
      authCubit: auth,
      syncStatusCubit: syncStatus,
      connectivityCubit: connectivity,
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> goTo(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
}
