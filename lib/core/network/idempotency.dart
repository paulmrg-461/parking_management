import 'package:dio/dio.dart';

const idempotencyHeader = 'Idempotency-Key';

/// Request options carrying `Idempotency-Key: <key>`, or `null` when [key]
/// is absent (online first attempts do not send one).
Options? idempotencyOptions(String? key) =>
    key == null ? null : Options(headers: {idempotencyHeader: key});
