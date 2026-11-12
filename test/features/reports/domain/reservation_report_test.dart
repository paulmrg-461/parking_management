import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/reservation_report.dart';

void main() {
  test('Success: the counts parse and the conversion is a percentage', () {
    final report = ReservationReport.fromJson({
      'total': 10,
      'public': 4,
      'app': 6,
      'used': 5,
      'used_public': 3,
      'cancelled': 2,
      'expired': 1,
      'active': 2,
    });

    expect(report.publicConversion, 75);
    expect(report.hasData, isTrue);
    expect(report.cancelled + report.expired, 3);
  });

  test('Failure: no web holds means no conversion to show', () {
    const report = ReservationReport(total: 2, app: 2);

    expect(report.publicConversion, isNull);
    expect(report.hasData, isTrue);
    expect(ReservationReport.empty.hasData, isFalse);
  });

  test('Success: the waitlist block parses', () {
    final report = ReservationReport.fromJson({
      'total': 3,
      'waitlist': {
        'joined': 9,
        'offered': 4,
        'claimed': 3,
        'expired': 1,
        'left': 2,
        'cancelled': 0,
        'waiting': 3,
      },
    });

    expect(report.waitlist.joined, 9);
    expect(report.waitlist.conversion, 75);
    expect(report.waitlist.hasData, isTrue);
  });

  test('Success: a database without the waitlist block parses as zeros', () {
    final report = ReservationReport.fromJson({'total': 1});

    expect(report.waitlist, WaitlistReport.empty);
    expect(report.waitlist.conversion, isNull);
    expect(report.waitlist.hasData, isFalse);
  });
}
