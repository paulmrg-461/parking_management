import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_resolution.dart';

void main() {
  test('Success: every status parses', () {
    for (final status in FiscalStatus.values) {
      final document = FiscalDocument.fromJson({
        'id': 1,
        'doc_type': 'pos',
        'full_number': 'SETP1',
        'status': status.wire,
      });
      expect(document.status, status);
    }
  });

  test('Success: a voided accepted document parses', () {
    final document = FiscalDocument.fromJson(const {
      'id': 3,
      'doc_type': 'invoice',
      'full_number': 'FE3',
      'status': 'accepted',
      'cufe': 'CUFE-3',
      'voided_at': '2026-11-18T10:00:00Z',
      'customer_doc_type': 'NIT',
      'customer_doc_number': '900123456',
    });
    expect(document.voided, isTrue);
    expect(document.customerDocType, FiscalIdType.nit);
    expect(document.status.canRetry, isFalse);
  });

  test('Success: a rejected document can be retried', () {
    final document = FiscalDocument.fromJson(const {
      'id': 4,
      'doc_type': 'pos',
      'full_number': 'SETP4',
      'status': 'rejected',
      'rejection_reason': 'NIT inválido',
      'attempts': 2,
    });
    expect(document.status.canRetry, isTrue);
    expect(document.rejectionReason, 'NIT inválido');
  });

  test('Failure: unknown codes fall back to pending/pos', () {
    final document = FiscalDocument.fromJson(const {});
    expect(document.status, FiscalStatus.pending);
    expect(document.docType, FiscalDocType.pos);
  });

  test('Success: the summary reads document_id or id', () {
    final summary = FiscalDocSummary.fromJson(const {
      'document_id': 9,
      'doc_type': 'credit_note',
      'full_number': 'NC1',
      'status': 'accepted',
      'cufe': 'C',
      'qr_data': 'https://qr/1',
    });
    expect(summary.documentId, 9);
    expect(summary.docType, FiscalDocType.creditNote);
    expect(summary.cufe, 'C');
    expect(summary.status.isAccepted, isTrue);
  });
}
