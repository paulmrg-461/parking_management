import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';
import 'package:parking_management/features/invoicing/infrastructure/invoicing_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabaseInvoicingRemoteDataSource remote, List<http.Request> sent}) _harness({
  Object? body,
  int status = 200,
  bool networkError = false,
}) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      if (networkError) {
        throw http.ClientException('offline', request.url);
      }
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (remote: SupabaseInvoicingRemoteDataSource(client), sent: sent);
}

String _rpc(http.Request request) => request.url.path.split('/rpc/').last;

void main() {
  test('Success: config calls fiscal_config', () async {
    final harness = _harness(
      body: {
        'mode': 'on_request',
        'has_pos_resolution': true,
        'has_invoice_resolution': false,
        'tax_rate_bps': 1900,
      },
    );
    final config = await harness.remote.config();
    expect(config.enabled, isTrue);
    expect(config.hasPosResolution, isTrue);
    expect(_rpc(harness.sent.single), 'fiscal_config');
  });

  test('Success: settings calls get_fiscal_settings', () async {
    final harness = _harness(
      body: {'mode': 'off', 'issuer_nit': null, 'tax_rate_bps': 1900},
    );
    final settings = await harness.remote.settings();
    expect(settings.mode, FiscalMode.off);
    expect(_rpc(harness.sent.single), 'get_fiscal_settings');
  });

  test('Success: saveSettings sends p_settings', () async {
    final harness = _harness(
      body: {
        'mode': 'on_request',
        'issuer_nit': '900123456',
        'issuer_legal_name': 'Fiscal SAS',
        'municipality_code': '11001',
        'tax_rate_bps': 1900,
      },
    );
    await harness.remote.saveSettings(
      const FiscalSettings(
        mode: FiscalMode.onRequest,
        issuerNit: '900123456',
        issuerLegalName: 'Fiscal SAS',
        municipalityCode: '11001',
      ),
    );
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect((body['p_settings'] as Map)['mode'], 'on_request');
    expect(_rpc(harness.sent.single), 'save_fiscal_settings');
  });

  test('Success: resolutions and saveResolution map the RPCs', () async {
    final harness = _harness(
      body: [
        {
          'id': 1,
          'doc_type': 'pos',
          'resolution_number': 'R1',
          'prefix': 'SETP',
          'range_from': 1,
          'range_to': 5000,
          'valid_from': '2026-01-01',
          'valid_to': '2027-01-01',
          'remaining': 10,
        },
      ],
    );
    final rows = await harness.remote.resolutions();
    expect(rows.single.remaining, 10);
    expect(_rpc(harness.sent.single), 'list_fiscal_resolutions');
  });

  test('Success: documents passes the filter and parses the total', () async {
    final harness = _harness(
      body: {
        'total': 1,
        'items': [
          {
            'id': 7,
            'doc_type': 'pos',
            'full_number': 'SETP7',
            'status': 'pending',
            'total': 11900,
            'tax_amount': 1900,
          },
        ],
      },
    );
    final page = await harness.remote.documents(
      status: FiscalStatus.pending,
      limit: 20,
      offset: 0,
    );
    expect(page.total, 1);
    expect(page.items.single.fullNumber, 'SETP7');
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_status'], 'pending');
    expect(body['p_limit'], 20);
  });

  test('Success: retry, credit and issuance send their params', () async {
    final harness = _harness(
      body: {
        'document_id': 7,
        'doc_type': 'pos',
        'full_number': 'SETP7',
        'status': 'pending',
      },
    );
    await harness.remote.retry(
      7,
      customer: const FiscalCustomer(
        documentType: FiscalIdType.nit,
        documentNumber: '900123456',
        name: 'Empresa',
      ),
    );
    var body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_document_id'], 7);
    expect((body['p_customer'] as Map)['document_type'], 'NIT');
    expect(_rpc(harness.sent.single), 'retry_fiscal_document');

    await harness.remote.requestCreditNote(7, 'Motivo');
    body = jsonDecode(harness.sent.last.body) as Map;
    expect(body['p_reason'], 'Motivo');

    await harness.remote.issueForSession(3);
    body = jsonDecode(harness.sent.last.body) as Map;
    expect(body['p_source_kind'], 'session');
    expect(body['p_source_id'], 3);

    await harness.remote.issueForPassPayment(9);
    body = jsonDecode(harness.sent.last.body) as Map;
    expect(body['p_source_kind'], 'pass_payment');
  });

  test('Success: documentForSession returns null without a document', () async {
    final harness = _harness(body: null);
    expect(await harness.remote.documentForSession(3), isNull);
  });

  test('Failure: a typed error becomes a Failure with its code', () {
    final harness = _harness(
      status: 400,
      body: {'message': 'FiscalResolutionMissingError'},
    );
    expect(
      () => harness.remote.issueForSession(3),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'FiscalResolutionMissingError',
        ),
      ),
    );
  });

  test('Failure: a network drop maps to NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(() => harness.remote.config(), throwsA(isA<NetworkFailure>()));
  });
}
