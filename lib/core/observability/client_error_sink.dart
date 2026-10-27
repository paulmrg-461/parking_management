/// Transport for client error reports. The Supabase implementation calls
/// `rpc/report_client_error`; tests use an in-memory fake.
abstract class ClientErrorSink {
  Future<void> send({
    required String platform,
    required String message,
    String? stack,
    Map<String, Object?> context,
  });
}
