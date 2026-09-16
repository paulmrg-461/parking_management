import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/config/app_config.dart';

void main() {
  group('AppConfig.fromEnvironment', () {
    test(
        'Success: reads apiBaseUrl from the API_BASE_URL dart-define '
        '(falls back to localhost when none is supplied at compile time)',
        () {
      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUrl, 'http://localhost:8000');
      expect(config.appName, 'Parking Management');
    });
  });
}
