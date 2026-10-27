import 'package:equatable/equatable.dart';

/// One queued customer WhatsApp message (`rpc/list_whatsapp_messages`).
class WhatsappMessage extends Equatable {
  const WhatsappMessage({
    required this.id,
    required this.toPhone,
    required this.template,
    required this.status,
    required this.createdAt,
    this.attempts = 0,
    this.error,
    this.sentAt,
    this.actor,
    this.lot,
  });

  final int id;
  final String toPhone;
  final String template;

  /// `pending`, `sent` or `failed`.
  final String status;
  final DateTime createdAt;
  final int attempts;
  final String? error;
  final DateTime? sentAt;
  final String? actor;
  final String? lot;

  factory WhatsappMessage.fromJson(Map<String, dynamic> json) =>
      WhatsappMessage(
        id: (json['id'] as num).toInt(),
        toPhone: json['to_phone'] as String? ?? '',
        template: json['template'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        error: json['error'] as String?,
        sentAt: switch (json['sent_at']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
        actor: json['actor'] as String?,
        lot: json['lot'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, toPhone, template, status, createdAt, attempts, error, sentAt];
}
