import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/features/audit/presentation/audit_export.dart';

import '../../../helpers/fake_audit_repository.dart';

void main() {
  test('Success: CSV has a header and quotes values with commas', () {
    final csv = auditCsv([
      sampleAudit(),
      sampleAudit(id: 2, table: 'users', actor: 'juan, admin'),
    ]);

    final lines = csv.split('\n');
    expect(lines.first, startsWith('created_at,actor,action,table'));
    expect(lines, hasLength(3));
    expect(lines[1], contains('tariffs'));
    expect(lines[2], contains('"juan, admin"'));
    expect(lines[1], contains('amount'));
  });

  test('Success: the audit PDF is a valid document', () async {
    final bytes = await buildAuditPdf(
      l10n: await AppLocalizations.delegate.load(defaultLocale),
      entries: [sampleAudit(), sampleAudit(id: 2, action: 'delete')],
      subtitle: 'tariffs · admin',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('Security: an empty log still renders a valid PDF', () async {
    final bytes = await buildAuditPdf(
      l10n: await AppLocalizations.delegate.load(defaultLocale),
      entries: const [],
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
