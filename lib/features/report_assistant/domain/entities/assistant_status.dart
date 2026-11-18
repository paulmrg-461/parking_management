import 'package:equatable/equatable.dart';

class AssistantStatus extends Equatable {
  const AssistantStatus({
    this.configured = false,
    this.dailyRequests = 0,
    this.usedRequests = 0,
    this.remainingRequests = 0,
    this.remainingTokens = 0,
  });

  final bool configured;
  final int dailyRequests;
  final int usedRequests;
  final int remainingRequests;
  final int remainingTokens;

  factory AssistantStatus.fromJson(Map<String, dynamic> json) {
    final budget = json['budget'] is Map
        ? Map<String, dynamic>.from(json['budget'] as Map)
        : const <String, dynamic>{};
    return AssistantStatus(
      configured: json['configured'] as bool? ?? false,
      dailyRequests: (budget['daily_requests'] as num?)?.toInt() ?? 0,
      usedRequests: (budget['used_requests'] as num?)?.toInt() ?? 0,
      remainingRequests:
          (budget['remaining_requests'] as num?)?.toInt() ?? 0,
      remainingTokens: (budget['remaining_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  AssistantStatus copyWith({int? remainingRequests, int? remainingTokens}) =>
      AssistantStatus(
        configured: configured,
        dailyRequests: dailyRequests,
        usedRequests: usedRequests,
        remainingRequests: remainingRequests ?? this.remainingRequests,
        remainingTokens: remainingTokens ?? this.remainingTokens,
      );

  @override
  List<Object?> get props => [
    configured,
    dailyRequests,
    usedRequests,
    remainingRequests,
    remainingTokens,
  ];
}

class AssistantQuestion extends Equatable {
  const AssistantQuestion({required this.text, this.locale = 'es'});

  final String text;
  final String locale;

  @override
  List<Object?> get props => [text, locale];
}
