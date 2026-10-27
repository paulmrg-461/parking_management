import 'package:parking_management/features/customer_messages/domain/repositories/customer_message_repository.dart';

class FakeCustomerMessageRepository implements CustomerMessageRepository {
  final List<({String phone, String template, List<String> params})> sent = [];

  @override
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    String language = 'es',
  }) async {
    sent.add((phone: phone, template: template, params: params));
  }
}
