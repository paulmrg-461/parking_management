import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/settings/domain/whatsapp_url.dart';

void main() {
  group('whatsappUrl', () {
    test('Success: normalizes an international number to a wa.me link', () {
      expect(
        whatsappUrl('+57 300 111 2233'),
        'https://wa.me/573001112233',
      );
    });

    test('Failure: an empty or digit-less value returns null', () {
      expect(whatsappUrl(''), isNull);
      expect(whatsappUrl('   +  '), isNull);
    });

    test('Security: the link never leaks + signs or spaces', () {
      final url = whatsappUrl('+57 (300) 111-2233')!;
      expect(RegExp(r'^https://wa\.me/\d+$').hasMatch(url), isTrue);
    });
  });
}
