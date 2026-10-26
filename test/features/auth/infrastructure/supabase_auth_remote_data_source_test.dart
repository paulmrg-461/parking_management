import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/infrastructure/supabase_auth_remote_data_source.dart';

void main() {
  test('Success: usernames map to the private parking.local email domain', () {
    expect(supabaseEmailFor('Operator'), 'operator@parking.local');
    expect(supabaseEmailFor('  ADMIN '), 'admin@parking.local');
  });

  test('Security: the domain is fixed even if the username has one', () {
    // A username containing '@' must never let a client pick another domain.
    expect(supabaseEmailFor('a@evil.example'), 'a@parking.local');
  });
}
