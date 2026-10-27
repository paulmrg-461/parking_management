import 'package:equatable/equatable.dart';

/// One uncaught error reported by a client (`rpc/list_client_error_reports`).
class ClientErrorReport extends Equatable {
  const ClientErrorReport({
    required this.id,
    required this.platform,
    required this.message,
    required this.createdAt,
    this.stack,
    this.context = const {},
    this.appVersion,
    this.actor,
  });

  final int id;
  final String platform;
  final String message;
  final DateTime createdAt;
  final String? stack;
  final Map<String, dynamic> context;
  final String? appVersion;
  final String? actor;

  factory ClientErrorReport.fromJson(Map<String, dynamic> json) =>
      ClientErrorReport(
        id: (json['id'] as num).toInt(),
        platform: json['platform'] as String? ?? 'unknown',
        message: json['message'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        stack: json['stack'] as String?,
        context: json['context'] is Map
            ? Map<String, dynamic>.from(json['context'] as Map)
            : const {},
        appVersion: json['app_version'] as String?,
        actor: json['actor'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, platform, message, createdAt, stack, context, appVersion, actor];
}
