import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';

void main() {
  test('Success: parses the billing breakdown from the server', () {
    final preview = CheckOutPreview.fromJson(const {
      'session_id': 12,
      'amount': 22000,
      'has_pass': false,
      'elapsed_seconds': 3900,
      'day_hours': 2,
      'night_hours': 1,
      'days': 1,
      'hourly_rate': 2000,
      'nightly_rate': 8000,
      'daily_rate': 30000,
      'daily_cap_applied': true,
    });

    expect(preview.sessionId, 12);
    expect(preview.amount, 22000);
    expect(preview.elapsed, const Duration(hours: 1, minutes: 5));
    expect(preview.dayHours, 2);
    expect(preview.nightHours, 1);
    expect(preview.hourlyRate, 2000);
    expect(preview.nightlyRate, 8000);
    expect(preview.dailyCapApplied, isTrue);
  });

  test('Failure: a bare preview stays usable with zeroed components', () {
    final preview = CheckOutPreview.fromJson(const {
      'session_id': 7,
      'amount': 5000,
    });

    expect(preview.amount, 5000);
    expect(preview.elapsed, Duration.zero);
    expect(preview.dayHours, 0);
    expect(preview.hourlyRate, isNull);
    expect(preview.dailyCapApplied, isFalse);
  });

  test('Security: a monthly pass preview never reports a charge', () {
    final preview = CheckOutPreview.fromJson(const {
      'session_id': 9,
      'amount': 0,
      'has_pass': true,
      'elapsed_seconds': 600,
      'day_hours': 0,
      'night_hours': 0,
      'days': 0,
      'hourly_rate': null,
      'nightly_rate': null,
      'daily_rate': null,
      'daily_cap_applied': false,
    });

    expect(preview.hasPass, isTrue);
    expect(preview.amount, 0);
    expect(preview.dayHours, 0);
    expect(preview.hourlyRate, isNull);
  });
}
