import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/config/app_config.dart';

void main() {
  group('AppConfig.fromEnvironment', () {
    test('Failure: Supabase is not configured by default', () {
      final config = AppConfig.fromEnvironment();

      expect(config.appName, 'Parking Management');
      expect(config.supabaseAuthEnabled, isFalse);
    });

    test('Success: Supabase is configured via dart-defines', () {
      const config = AppConfig(
        appName: 'Parking',
        supabaseUrl: 'http://localhost:8000',
        supabaseAnonKey: 'anon-key',
      );

      expect(config.supabaseAuthEnabled, isTrue);
    });

    test('Failure: a URL without an anon key is not usable', () {
      const config = AppConfig(
        appName: 'Parking',
        supabaseUrl: 'http://localhost:8000',
        supabaseAnonKey: '',
      );

      expect(config.supabaseAuthEnabled, isFalse);
    });
  });
}
