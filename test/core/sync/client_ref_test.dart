import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/client_ref.dart';

void main() {
  test('Success: format is <micros>-<32 hex chars>', () {
    expect(newClientRef(), matches(RegExp(r'^\d+-[0-9a-f]{32}$')));
  });

  test('Failure: consecutive refs never collide', () {
    final refs = {for (var i = 0; i < 500; i++) newClientRef()};

    expect(refs, hasLength(500));
  });

  test('Security: the random suffix uses the full 32-bit range per chunk', () {
    final chunks = {
      for (var i = 0; i < 200; i++)
        ...RegExp(r'[0-9a-f]{8}')
            .allMatches(newClientRef().split('-').last)
            .map((m) => m.group(0)!),
    };

    expect(chunks.any((c) => int.parse(c, radix: 16) > 0x7fffffff), isTrue);
  });
}
