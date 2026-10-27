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

  test('Success: a prefilled message is URL-encoded', () {
    final url = whatsappUrl('+57 300 111 2233', text: 'Hola, total: \$5.000');

    expect(url, startsWith('https://wa.me/573001112233?text='));
    expect(url, contains('Hola%2C%20total'));
  });

  test('Security: an empty message keeps the plain link', () {
    expect(whatsappUrl('3001112233', text: '   '), 'https://wa.me/3001112233');
  });
}
