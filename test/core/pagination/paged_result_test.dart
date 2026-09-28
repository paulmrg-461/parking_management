import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/network/pagination.dart';
import 'package:parking_management/core/pagination/paged_result.dart';

Response<Object?> _response(Map<String, List<String>> headers) => Response(
  requestOptions: RequestOptions(path: '/api/vehicles'),
  headers: Headers.fromMap(headers),
);

void main() {
  test('Success: X-Total-Count drives hasMoreAfter', () {
    final total = totalCountOf(
      _response({
        'x-total-count': ['120'],
      }),
    );
    final page = PagedResult<int>(const [1, 2], total: total);

    expect(total, 120);
    expect(page.hasMoreAfter(50), isTrue);
    expect(page.hasMoreAfter(120), isFalse);
  });

  test('Failure: without the header there is never a next page', () {
    final page = PagedResult<int>(const [
      1,
    ], total: totalCountOf(_response(const {})));

    expect(page.total, isNull);
    expect(page.hasMoreAfter(1), isFalse);
  });

  test('Security: malformed or negative totals are ignored', () {
    expect(
      totalCountOf(
        _response({
          'x-total-count': ['abc'],
        }),
      ),
      isNull,
    );
    expect(
      totalCountOf(
        _response({
          'x-total-count': ['-1'],
        }),
      ),
      isNull,
    );
    expect(pageQuery(limit: 0, offset: -3), {'limit': 1, 'offset': 0});
  });
}
