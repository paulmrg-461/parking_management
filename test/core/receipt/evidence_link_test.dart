import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/evidence_link.dart';

void main() {
  test('Success: builds the public URL with the plate as key', () {
    final url = publicEvidenceUrl(
      43,
      'abc 123',
      base: 'https://app.example.com/',
    );

    expect(url, 'https://app.example.com/evidence?session=43&plate=ABC123');
  });

  test('Failure: without an app URL there is nothing to print', () {
    expect(publicEvidenceUrl(43, 'ABC123', base: ''), isNull);
  });

  test('Security: the link never carries anything but session and plate', () {
    final uri = publicEvidenceUri(43, 'ABC123', base: 'https://app.test')!;

    expect(uri.queryParameters.keys.toSet(), {'session', 'plate'});
  });
}
