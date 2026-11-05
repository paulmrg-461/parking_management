import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/version/app_version.dart';

void main() {
  test('Success: compares numeric segments, not strings', () {
    expect(compareVersions('1.2.3', '1.2.3'), 0);
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0', '1.0.1'), lessThan(0));
  });

  test('Failure: malformed versions never mark the app outdated', () {
    expect(isVersionOutdated('1.0.0', ''), isFalse);
    expect(isVersionOutdated('1.0.0', null), isFalse);
    expect(isVersionOutdated('1.0.0', 'v1'), isFalse);
    expect(parseVersion('1.x'), isNull);
  });

  test('Security: an older build is flagged against the site minimum', () {
    expect(isVersionOutdated('1.4.2', '1.4.3'), isTrue);
    expect(isVersionOutdated('1.4.3', '1.4.3'), isFalse);
    expect(isVersionOutdated('2.0.0', '1.9.9'), isFalse);
  });
}
