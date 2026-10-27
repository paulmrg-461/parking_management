import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/app_notification.dart';

abstract class NotificationRemoteDataSource {
  Future<List<AppNotification>> list({int limit});

  Future<int> markRead({List<int>? ids});

  Stream<AppNotification> watch(int? userId);

  Future<void> registerDeviceToken(String token, String platform);

  Future<void> unregisterDeviceToken(String token);
}

class SupabaseNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  SupabaseNotificationRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'notifications';

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final row in rows) AppNotification.fromJson(row)];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<int> markRead({List<int>? ids}) async {
    try {
      final result = await _client.rpc(
        'mark_notifications_read',
        params: ids == null ? const <String, dynamic>{} : {'p_ids': ids},
      );
      return (result as num).toInt();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> registerDeviceToken(String token, String platform) async {
    try {
      await _client.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': platform},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _client.rpc(
        'unregister_device_token',
        params: {'p_token': token},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Stream<AppNotification> watch(int? userId) {
    final controller = StreamController<AppNotification>.broadcast();
    final channel = _client.channel('notifications:${userId ?? 'me'}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: _table,
      filter: userId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
      callback: (payload) {
        try {
          controller.add(AppNotification.fromJson(payload.newRecord));
        } catch (error) {
          controller.addError(error);
        }
      },
    ).subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }
}
