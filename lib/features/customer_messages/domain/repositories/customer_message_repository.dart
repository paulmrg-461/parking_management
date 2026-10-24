/// Queues a customer WhatsApp message. The Edge Function holds the Meta token;
/// the app only enqueues (and only when the site enabled `whatsapp_auto`).
abstract class CustomerMessageRepository {
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    String language = 'es',
  });
}
