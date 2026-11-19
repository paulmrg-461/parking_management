import 'package:equatable/equatable.dart';

enum FigureUnit {
  money,
  count,
  percent,
  hour;

  static FigureUnit parse(String? value) => switch (value) {
    'money' => FigureUnit.money,
    'count' => FigureUnit.count,
    'percent' => FigureUnit.percent,
    _ => FigureUnit.hour,
  };
}

enum AnswerStatus {
  answered,
  needsClarification,
  outOfScope,
  noData;

  static AnswerStatus parse(String? value) => switch (value) {
    'answered' => AnswerStatus.answered,
    'needs_clarification' => AnswerStatus.needsClarification,
    'out_of_scope' => AnswerStatus.outOfScope,
    _ => AnswerStatus.noData,
  };
}

class FigureSource extends Equatable {
  const FigureSource({
    required this.callId,
    required this.rpc,
    required this.args,
    required this.path,
    required this.raw,
  });

  final String callId;
  final String rpc;
  final Map<String, String> args;
  final String path;
  final int raw;

  factory FigureSource.fromJson(Map<String, dynamic> json) => FigureSource(
    callId: json['call_id'] as String? ?? '',
    rpc: json['rpc'] as String? ?? '',
    args: {
      for (final entry in (json['args'] as Map? ?? const {}).entries)
        entry.key.toString(): entry.value.toString(),
    },
    path: json['path'] as String? ?? '',
    raw: (json['raw'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [callId, rpc, args, path, raw];
}

class AssistantFigure extends Equatable {
  const AssistantFigure({
    required this.id,
    required this.label,
    required this.unit,
    required this.op,
    this.value,
    this.note,
    this.sources = const [],
  });

  final String id;
  final String label;
  final FigureUnit unit;
  final String op;
  final int? value;
  final String? note;
  final List<FigureSource> sources;

  factory AssistantFigure.fromJson(Map<String, dynamic> json) =>
      AssistantFigure(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        unit: FigureUnit.parse(json['unit'] as String?),
        op: json['op'] as String? ?? 'value',
        value: (json['value'] as num?)?.toInt(),
        note: json['note'] as String?,
        sources: [
          for (final item in (json['sources'] as List? ?? const []))
            if (item is Map) FigureSource.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  @override
  List<Object?> get props => [id, label, unit, op, value, note, sources];
}

class AssistantAnswer extends Equatable {
  const AssistantAnswer({
    required this.status,
    required this.headline,
    required this.explanation,
    this.periodStart,
    this.periodEnd,
    this.currency = 'COP',
    this.figures = const [],
    this.caveats = const [],
    this.questionRedacted = false,
    this.requestId = 0,
  });

  final AnswerStatus status;
  final String headline;
  final String explanation;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String currency;
  final List<AssistantFigure> figures;
  final List<String> caveats;
  final bool questionRedacted;
  final int requestId;

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) =>
      AssistantAnswer(
        status: AnswerStatus.parse(json['status'] as String?),
        headline: json['headline'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        periodStart: DateTime.tryParse(json['period_start'] as String? ?? ''),
        periodEnd: DateTime.tryParse(json['period_end'] as String? ?? ''),
        currency: json['currency'] as String? ?? 'COP',
        figures: [
          for (final item in (json['figures'] as List? ?? const []))
            if (item is Map) AssistantFigure.fromJson(Map<String, dynamic>.from(item)),
        ],
        caveats: [
          for (final item in (json['caveats'] as List? ?? const []))
            item.toString(),
        ],
        questionRedacted: json['question_redacted'] as bool? ?? false,
        requestId: (json['request_id'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
    status,
    headline,
    explanation,
    periodStart,
    periodEnd,
    currency,
    figures,
    caveats,
    questionRedacted,
    requestId,
  ];
}
