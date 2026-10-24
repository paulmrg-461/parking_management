import '../domain/repositories/customer_message_repository.dart';
import 'customer_message_remote_data_source.dart';

class CustomerMessageRepositoryImpl implements CustomerMessageRepository {
  CustomerMessageRepositoryImpl(this._remote);

  final CustomerMessageRemoteDataSource _remote;

  @override
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    String language = 'es',
  }) => _remote.enqueueWhatsapp(
    phone: phone,
    template: template,
    params: params,
    language: language,
  );
}
