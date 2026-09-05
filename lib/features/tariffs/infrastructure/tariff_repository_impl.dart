import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import '../domain/repositories/tariff_repository.dart';
import 'tariff_local_data_source.dart';
import 'tariff_remote_data_source.dart';

class TariffRepositoryImpl implements TariffRepository {
  TariffRepositoryImpl(this._auth, this._remote, this._local);

  final AuthRepository _auth;
  final TariffRemoteDataSource _remote;
  final TariffLocalDataSource _local;

  @override
  Future<List<Tariff>> list() async {
    final token = await _currentToken();
    try {
      final tariffs = await _remote.list(token);
      await _local.cacheAll(tariffs);
      return tariffs;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Tariff> create(CreateTariffCommand command) async {
    return _remote.create(await _currentToken(), _toCreatePayload(command));
  }

  @override
  Future<Tariff> update(UpdateTariffCommand command) async {
    return _remote.update(
      await _currentToken(),
      command.id,
      _toUpdatePayload(command),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(await _currentToken(), id);
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }

  Map<String, dynamic> _toCreatePayload(CreateTariffCommand command) => {
        'category_id': command.categoryId,
        'type': command.type.name,
        'amount': command.amount,
        'start_time': command.startTime,
        'end_time': command.endTime,
      };

  Map<String, dynamic> _toUpdatePayload(UpdateTariffCommand command) => {
        if (command.type != null) 'type': command.type!.name,
        if (command.amount != null) 'amount': command.amount,
        if (command.startTime != null) 'start_time': command.startTime,
        if (command.endTime != null) 'end_time': command.endTime,
        if (command.active != null) 'active': command.active,
      };
}
