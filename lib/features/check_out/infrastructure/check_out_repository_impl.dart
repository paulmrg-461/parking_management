import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import '../domain/repositories/check_out_repository.dart';
import 'check_out_remote_data_source.dart';

/// Check-out is inherently an online action (no offline local cache), same
/// remote-only convention as check-in.
class CheckOutRepositoryImpl implements CheckOutRepository {
  CheckOutRepositoryImpl(this._auth, this._remote);

  final AuthRepository _auth;
  final CheckOutRemoteDataSource _remote;

  @override
  Future<List<OpenSession>> listOpenSessions() async {
    return _remote.listOpenSessions(await _currentToken());
  }

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async {
    return _remote.checkOut(await _currentToken(), sessionId);
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
