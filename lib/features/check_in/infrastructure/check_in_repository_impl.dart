import 'dart:io';

import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/parking_session.dart';
import '../domain/repositories/check_in_repository.dart';
import 'check_in_remote_data_source.dart';

/// Check-in is inherently an online action (no offline local cache), similar
/// to how vehicle mutations are remote-only in this project's convention.
class CheckInRepositoryImpl implements CheckInRepository {
  CheckInRepositoryImpl(this._auth, this._remote);

  final AuthRepository _auth;
  final CheckInRemoteDataSource _remote;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    return _remote.createCheckIn(
      await _currentToken(),
      plate: plate,
      photos: photos,
    );
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async {
    return _remote.listOpenSessions(await _currentToken());
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
