import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/realtime/local_activity.dart';

void main() {
  tearDown(LocalActivity.clear);

  test('Success: a remembered action is owned during the echo window', () {
    final at = DateTime(2026, 10, 28, 12);
    LocalActivity.remember('check_in', 7, at: at);

    expect(
      LocalActivity.owns('check_in', 7, now: at.add(const Duration(seconds: 5))),
      isTrue,
    );
  });

  test('Failure: the same action on another session is not ours', () {
    LocalActivity.remember('check_in', 7);

    expect(LocalActivity.owns('check_in', 8), isFalse);
    expect(LocalActivity.owns('check_out', 7), isFalse);
  });

  test('Security: a stale echo stops being ours after the window', () {
    final at = DateTime(2026, 10, 28, 12);
    LocalActivity.remember('check_out', 7, at: at);

    expect(
      LocalActivity.owns(
        'check_out',
        7,
        now: at.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });
}
