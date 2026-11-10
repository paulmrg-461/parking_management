import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/public_booking/domain/phone_rules.dart';

void main() {
  test('Success: a 10-digit mobile is accepted as is', () {
    expect(normalizeMobilePhone('3001112233'), '3001112233');
    expect(normalizeMobilePhone('300 111 2233'), '3001112233');
  });

  test('Success: the +57 country code is stripped', () {
    expect(normalizeMobilePhone('+57 300 111 2233'), '3001112233');
    expect(normalizeMobilePhone('573001112233'), '3001112233');
  });

  test('Failure: landlines, short numbers and foreign codes are rejected', () {
    expect(normalizeMobilePhone(''), isNull);
    expect(normalizeMobilePhone('300111223'), isNull);
    expect(normalizeMobilePhone('6011234567'), isNull);
    expect(normalizeMobilePhone('123'), isNull);
    expect(normalizeMobilePhone('+1 305 555 1234'), isNull);
    expect(normalizeMobilePhone('30011122334'), isNull);
  });
}
