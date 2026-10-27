import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/customer_messages/domain/repositories/customer_message_repository.dart';
import 'package:parking_management/features/customer_messages/infrastructure/customer_message_remote_data_source.dart';
import 'package:parking_management/features/customer_messages/infrastructure/customer_message_repository_impl.dart';

class _FakeRemote implements CustomerMessageRemoteDataSource {
  String? phone;
  String? template;
  List<String>? params;
  String? language;

  @override
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    required String language,
  }) async {
    this.phone = phone;
    this.template = template;
    this.params = params;
    this.language = language;
  }
}

void main() {
  test('Success: the queue payload keeps the template and params', () async {
    final remote = _FakeRemote();
    final CustomerMessageRepository repository =
        CustomerMessageRepositoryImpl(remote);

    await repository.enqueueWhatsapp(
      phone: '573001112233',
      template: 'receipt',
      params: const ['ABC123', '5.000', 'TCK-DEF-1'],
    );

    expect(remote.phone, '573001112233');
    expect(remote.template, 'receipt');
    expect(remote.params, ['ABC123', '5.000', 'TCK-DEF-1']);
    expect(remote.language, 'es');
  });
}
