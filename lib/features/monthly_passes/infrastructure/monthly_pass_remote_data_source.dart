import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/entities/monthly_pass_payment.dart';
import 'models/monthly_pass_dto.dart';

abstract class MonthlyPassRemoteDataSource {
  Future<List<MonthlyPass>> list({int? vehicleId});

  Future<MonthlyPass> create(Map<String, dynamic> payload);

  Future<MonthlyPass> update(int id, Map<String, dynamic> payload);

  Future<void> delete(int id);

  Future<List<MonthlyPassPayment>> pendingPayments();

  Future<MonthlyPassPayment> registerPayment(int id, String method);
}

class SupabaseMonthlyPassRemoteDataSource implements MonthlyPassRemoteDataSource {
  SupabaseMonthlyPassRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'monthly_passes';

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
    try {
      var query = _client.from(_table).select();
      if (vehicleId != null) {
        query = query.eq('vehicle_id', vehicleId);
      }
      final rows = await query.order('id');
      return rows
          .map((row) => MonthlyPassDto.fromJson(row).toDomain())
          .toList();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MonthlyPass> create(Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .insert(payload)
          .select()
          .single();
      return MonthlyPassDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MonthlyPass> update(int id, Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return MonthlyPassDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<MonthlyPassPayment>> pendingPayments() async {
    try {
      final result = await _client.rpc('pending_pass_payments');
      return [
        for (final item in (result as List<dynamic>))
          MonthlyPassPayment.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MonthlyPassPayment> registerPayment(int id, String method) async {
    try {
      final result = await _client.rpc(
        'register_pass_payment',
        params: {'p_payment_id': id, 'p_payment_method': method},
      );
      // The RPC returns a compact payment row; pendingPayments() has the full
      // pass/vehicle context, so use a synthetic date-only shape here.
      final map = Map<String, dynamic>.from(result as Map);
      final now = DateTime.now();
      return MonthlyPassPayment(
        id: (map['id'] as num).toInt(),
        monthlyPassId: (map['monthly_pass_id'] as num).toInt(),
        vehicleId: 0,
        plate: map['plate'] as String? ?? '',
        startDate: now,
        endDate: now,
        amount: (map['amount'] as num).toInt(),
        paymentMethod: map['payment_method'] as String,
        status: map['status'] as String,
        dueDate: now,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
