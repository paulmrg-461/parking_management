import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/pagination/paged_result.dart';
import '../domain/entities/fiscal_customer.dart';
import '../domain/entities/fiscal_document.dart';
import '../domain/entities/fiscal_resolution.dart';
import '../domain/entities/fiscal_settings.dart';

abstract class InvoicingRemoteDataSource {
  Future<FiscalConfig> config();
  Future<FiscalSettings> settings();
  Future<FiscalSettings> saveSettings(FiscalSettings settings);
  Future<List<FiscalResolution>> resolutions();
  Future<FiscalResolution> saveResolution(FiscalResolution resolution);
  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit,
    int offset,
  });
  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer});
  Future<FiscalDocSummary> requestCreditNote(int id, String reason);
  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  });
  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  });
  Future<FiscalDocSummary?> documentForSession(int sessionId);
}

class SupabaseInvoicingRemoteDataSource implements InvoicingRemoteDataSource {
  SupabaseInvoicingRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<FiscalConfig> config() async {
    try {
      final result = await _client.rpc('fiscal_config');
      return FiscalConfig.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalSettings> settings() async {
    try {
      final result = await _client.rpc('get_fiscal_settings');
      return FiscalSettings.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalSettings> saveSettings(FiscalSettings settings) async {
    try {
      final result = await _client.rpc(
        'save_fiscal_settings',
        params: {'p_settings': settings.toJson()},
      );
      return FiscalSettings.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<FiscalResolution>> resolutions() async {
    try {
      final result = await _client.rpc('list_fiscal_resolutions');
      return [
        for (final item in (result as List? ?? const []))
          if (item is Map)
            FiscalResolution.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalResolution> saveResolution(FiscalResolution resolution) async {
    try {
      final result = await _client.rpc(
        'save_fiscal_resolution',
        params: {'p_resolution': resolution.toJson()},
      );
      return FiscalResolution.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'list_fiscal_documents',
        params: {'p_status': status?.wire, 'p_limit': limit, 'p_offset': offset},
      );
      final map = Map<String, dynamic>.from(result as Map);
      return PagedResult(
        [
          for (final item in (map['items'] as List? ?? const []))
            if (item is Map)
              FiscalDocument.fromJson(Map<String, dynamic>.from(item)),
        ],
        total: (map['total'] as num?)?.toInt(),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer}) async {
    try {
      final result = await _client.rpc(
        'retry_fiscal_document',
        params: {'p_document_id': id, 'p_customer': customer?.toJson()},
      );
      return FiscalDocSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalDocSummary> requestCreditNote(int id, String reason) async {
    try {
      final result = await _client.rpc(
        'request_credit_note',
        params: {'p_document_id': id, 'p_reason': reason},
      );
      return FiscalDocSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  }) => _issue('session', sessionId, customer);

  @override
  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  }) => _issue('pass_payment', paymentId, customer);

  Future<FiscalDocSummary> _issue(
    String kind,
    int id,
    FiscalCustomer? customer,
  ) async {
    try {
      final result = await _client.rpc(
        'issue_fiscal_document',
        params: {
          'p_source_kind': kind,
          'p_source_id': id,
          'p_customer': customer?.toJson(),
        },
      );
      return FiscalDocSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FiscalDocSummary?> documentForSession(int sessionId) async {
    try {
      final result = await _client.rpc(
        'fiscal_document_for_session',
        params: {'p_session_id': sessionId},
      );
      if (result is! Map) {
        return null;
      }
      return FiscalDocSummary.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
