import 'package:dio/dio.dart';

const totalCountHeader = 'x-total-count';

/// `X-Total-Count` as a non-negative int, or `null` when absent/invalid.
int? totalCountOf(Response<Object?> response) {
  final raw = response.headers.value(totalCountHeader);
  final total = raw == null ? null : int.tryParse(raw.trim());
  return total == null || total < 0 ? null : total;
}

/// `limit`/`offset` query parameters, clamped to sane values.
Map<String, int> pageQuery({required int limit, required int offset}) => {
  'limit': limit < 1 ? 1 : limit,
  'offset': offset < 0 ? 0 : offset,
};
