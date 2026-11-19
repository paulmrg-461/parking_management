import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';

void main() {
  test('Success: a valid CC is accepted', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.cc,
      documentNumber: '1020304050',
      name: 'Ana Pérez',
      email: 'ana@test.co',
    );
    expect(customer.isValid, isTrue);
  });

  test('Success: a NIT with nine digits is accepted', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.nit,
      documentNumber: '900123456',
      name: 'Empresa SAS',
    );
    expect(customer.isValid, isTrue);
  });

  test('Failure: a short number is rejected', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.cc,
      documentNumber: '12',
      name: 'Ana',
    );
    expect(customer.isValid, isFalse);
  });

  test('Failure: a bad email is rejected', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.cc,
      documentNumber: '1020304050',
      name: 'Ana',
      email: 'nope',
    );
    expect(customer.isValid, isFalse);
  });

  test('Success: an empty email is allowed', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.cc,
      documentNumber: '1020304050',
      name: 'Ana',
      email: '',
    );
    expect(customer.normalized().email, isNull);
    expect(customer.isValid, isTrue);
  });

  test('Success: the name is trimmed and the number normalised', () {
    const customer = FiscalCustomer(
      documentType: FiscalIdType.nit,
      documentNumber: ' 900 123 456 ',
      name: '  Empresa SAS  ',
    );
    final normalized = customer.normalized();
    expect(normalized.name, 'Empresa SAS');
    expect(normalized.documentNumber, '900123456');
    expect(customer.toJson()['document_type'], 'NIT');
  });
}
