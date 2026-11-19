import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_resolution.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';
import 'package:parking_management/features/invoicing/domain/repositories/invoicing_repository.dart';

final sampleDocument = FiscalDocument(
  id: 7,
  docType: FiscalDocType.pos,
  fullNumber: 'SETP7',
  status: FiscalStatus.pending,
  total: 11900,
  taxAmount: 1900,
  issuedAt: DateTime(2026, 11, 18),
  sourceKind: 'session',
  sourceId: 3,
);

final sampleSummary = FiscalDocSummary(
  documentId: 7,
  docType: FiscalDocType.pos,
  fullNumber: 'SETP7',
  status: FiscalStatus.pending,
  total: 11900,
  taxAmount: 1900,
  issuedAt: DateTime(2026, 11, 18),
);

class FakeInvoicingRepository implements InvoicingRepository {
  FakeInvoicingRepository({
    this.configResult = const FiscalConfig(mode: FiscalMode.onRequest),
    this.settingsResult = const FiscalSettings(
      mode: FiscalMode.onRequest,
      issuerNit: '900123456',
      issuerLegalName: 'Fiscal SAS',
      municipalityCode: '11001',
    ),
    List<FiscalResolution>? resolutions,
    List<FiscalDocument>? documents,
    this.total,
  }) : resolutionRows =
           resolutions ??
           [
             FiscalResolution(
               id: 1,
               docType: FiscalDocType.pos,
               resolutionNumber: '18760000001',
               prefix: 'SETP',
               rangeFrom: 1,
               rangeTo: 5000,
               validFrom: DateTime(2026, 1, 1),
               validTo: DateTime(2027, 1, 1),
               remaining: 4990,
             ),
           ],
       documentRows = documents ?? [sampleDocument];

  FiscalConfig configResult;
  FiscalSettings settingsResult;
  List<FiscalResolution> resolutionRows;
  List<FiscalDocument> documentRows;
  int? total;
  Failure? loadError;
  Failure? writeError;
  int saveSettingsCalls = 0;
  int saveResolutionCalls = 0;
  int retryCalls = 0;
  int creditCalls = 0;
  int issueCalls = 0;
  FiscalCustomer? lastCustomer;
  String? lastCreditReason;
  FiscalSettings? lastSavedSettings;

  void _throwIfWriteFails() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<FiscalConfig> config() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return configResult;
  }

  @override
  Future<FiscalSettings> settings() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return settingsResult;
  }

  @override
  Future<FiscalSettings> saveSettings(FiscalSettings settings) async {
    _throwIfWriteFails();
    saveSettingsCalls++;
    lastSavedSettings = settings;
    settingsResult = settings;
    return settings;
  }

  @override
  Future<List<FiscalResolution>> resolutions() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return List.of(resolutionRows);
  }

  @override
  Future<FiscalResolution> saveResolution(FiscalResolution resolution) async {
    _throwIfWriteFails();
    saveResolutionCalls++;
    resolutionRows = [...resolutionRows, resolution];
    return resolution;
  }

  @override
  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    final rows = status == null
        ? documentRows
        : [for (final row in documentRows) if (row.status == status) row];
    return PagedResult(rows, total: total ?? rows.length);
  }

  @override
  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer}) async {
    _throwIfWriteFails();
    retryCalls++;
    lastCustomer = customer;
    return sampleSummary;
  }

  @override
  Future<FiscalDocSummary> requestCreditNote(int id, String reason) async {
    _throwIfWriteFails();
    creditCalls++;
    lastCreditReason = reason;
    return FiscalDocSummary(
      documentId: 9,
      docType: FiscalDocType.creditNote,
      fullNumber: 'NC1',
      status: FiscalStatus.pending,
    );
  }

  @override
  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  }) async {
    issueCalls++;
    lastCustomer = customer;
    _throwIfWriteFails();
    return sampleSummary;
  }

  @override
  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  }) async {
    issueCalls++;
    lastCustomer = customer;
    _throwIfWriteFails();
    return sampleSummary;
  }

  @override
  Future<FiscalDocSummary?> documentForSession(int sessionId) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return sampleSummary;
  }
}
