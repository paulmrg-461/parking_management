import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/utils/maps_launcher.dart';

void main() {
  test('Success: the address becomes a Maps search URL', () {
    final url = mapsUrl('Tv 7 #51N-24');

    expect(url, isNotNull);
    expect(url!.host, 'www.google.com');
    expect(url.path, '/maps/search/');
    expect(url.queryParameters['api'], '1');
    expect(url.queryParameters['query'], 'Tv 7 #51N-24');
  });

  test('Success: the address is trimmed', () {
    expect(mapsUrl('  Calle 1  ')!.queryParameters['query'], 'Calle 1');
  });

  test('Failure: no address means no URL', () {
    expect(mapsUrl(''), isNull);
    expect(mapsUrl('   '), isNull);
    expect(mapsUrl(null), isNull);
  });
}
