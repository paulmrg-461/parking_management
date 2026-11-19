import '../../../core/error/failure.dart';
import '../domain/entities/fiscal_customer.dart';
import '../domain/entities/fiscal_document.dart';
import '../domain/entities/fiscal_settings.dart';
import '../domain/repositories/invoicing_repository.dart';

/// Issues the fiscal document after a successful online check-out or pass
/// charge. It NEVER throws into the money flow: a disabled program, an offline
/// device or any failure returns null and the receipt simply omits the line.
class IssueFiscalDocument {
  const IssueFiscalDocument(this._repository);

  final InvoicingRepository _repository;

  Future<FiscalDocSummary?> forSession(
    int sessionId, {
    FiscalConfig? config,
    FiscalCustomer? customer,
    bool online = true,
  }) => _issue(
    config: config,
    online: online,
    customer: customer,
    action: () => _repository.issueForSession(sessionId, customer: customer),
  );

  Future<FiscalDocSummary?> forPassPayment(
    int paymentId, {
    FiscalConfig? config,
    FiscalCustomer? customer,
    bool online = true,
  }) => _issue(
    config: config,
    online: online,
    customer: customer,
    action: () => _repository.issueForPassPayment(paymentId, customer: customer),
  );

  Future<FiscalDocSummary?> _issue({
    required FiscalConfig? config,
    required bool online,
    required FiscalCustomer? customer,
    required Future<FiscalDocSummary> Function() action,
  }) async {
    if (!online || config == null || !config.enabled) {
      return null;
    }
    if (customer != null && !customer.isValid) {
      return null;
    }
    try {
      return await action();
    } on Failure {
      return null;
    }
  }
}
