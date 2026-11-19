import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/feedback_link.dart';

void main() {
  test('Success: the survey link carries the session and the plate', () {
    final url = publicFeedbackUrl(
      7,
      plate: ' abc123 ',
      base: 'https://app.example.com/',
    );

    expect(url, 'https://app.example.com/feedback?session=7&plate=ABC123');
  });

  test('Success: a link without a plate still opens the gate', () {
    final uri = publicFeedbackUri(7, plate: '', base: 'https://app.test')!;

    expect(uri.queryParameters.keys.toSet(), {'session'});
  });

  test('Failure: without an app URL there is nothing to print', () {
    expect(publicFeedbackUrl(7, plate: 'ABC123', base: ''), isNull);
  });

  test('Failure: an invalid session id has no link', () {
    expect(
      publicFeedbackUrl(0, plate: 'ABC123', base: 'https://app.test'),
      isNull,
    );
  });
}
