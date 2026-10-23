import 'package:equatable/equatable.dart';

/// A notification addressed to the signed-in user.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.isRead = false,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(
          (json['data'] as Map?) ?? const {},
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['read_at'] != null,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'created_at': createdAt.toUtc().toIso8601String(),
    'read_at': isRead ? createdAt.toUtc().toIso8601String() : null,
  };

  @override
  List<Object?> get props => [id, type, title, body, data, createdAt, isRead];
}
