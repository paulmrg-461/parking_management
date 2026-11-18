import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_answer.dart';
import 'package:parking_management/features/report_assistant/domain/figure_verifier.dart';

const _json = {
  'status': 'answered',
  'headline': 'Revenue was {f1}.',
  'explanation': 'Source: revenue.',
  'period_start': '2026-10-01',
  'period_end': '2026-10-31',
  'currency': 'COP',
  'figures': [
    {
      'id': 'f1',
      'label': 'Revenue',
      'unit': 'money',
      'op': 'value',
      'value': 4820000,
      'sources': [
        {
          'call_id': 'call1',
          'rpc': 'report_revenue',
          'args': {'p_start_date': '2026-10-01'},
          'path': 'total',
          'raw': 4820000,
        },
      ],
    },
  ],
  'caveats': <String>[],
  'question_redacted': false,
  'request_id': 7,
};

void main() {
  test('Success: parses the answer with figures and sources', () {
    final answer = AssistantAnswer.fromJson(Map<String, dynamic>.from(_json));
    expect(answer.status, AnswerStatus.answered);
    expect(answer.figures.single.sources.single.rpc, 'report_revenue');
    expect(answer.periodStart, DateTime(2026, 10, 1));
    expect(answer.requestId, 7);
  });

  test('Failure: unknown status falls back to no data', () {
    final answer = AssistantAnswer.fromJson({'status': 'bogus'});
    expect(answer.status, AnswerStatus.noData);
    expect(answer.figures, isEmpty);
  });

  test('Success: a null value with undefined_base parses', () {
    final answer = AssistantAnswer.fromJson({
      'status': 'answered',
      'figures': [
        {'id': 'f1', 'label': 'x', 'unit': 'percent', 'op': 'percent_change', 'value': null, 'note': 'undefined_base'},
      ],
    });
    expect(answer.figures.single.value, isNull);
    expect(answer.figures.single.note, 'undefined_base');
  });

  test('Success: missing optional fields use defaults', () {
    final answer = AssistantAnswer.fromJson(const {});
    expect(answer.headline, '');
    expect(answer.currency, 'COP');
    expect(answer.caveats, isEmpty);
  });

  test('Success: the verifier recomputes every operation', () {
    final answer = AssistantAnswer.fromJson(Map<String, dynamic>.from(_json));
    expect(FigureVerifier.verify(answer.figures.single), isTrue);

    const difference = AssistantFigure(
      id: 'f1', label: 'd', unit: FigureUnit.count, op: 'difference',
      value: 2,
      sources: [
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'a', raw: 5),
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'b', raw: 3),
      ],
    );
    expect(FigureVerifier.verify(difference), isTrue);
  });

  test('Failure: the verifier detects a tampered value or unit mismatch', () {
    final answer = AssistantAnswer.fromJson(Map<String, dynamic>.from(_json));
    final tampered = AssistantFigure(
      id: 'f1', label: 'x', unit: FigureUnit.money, op: 'value',
      value: 1, sources: answer.figures.single.sources,
    );
    expect(FigureVerifier.verify(tampered), isFalse);
  });

  test('Success: percent change is verified in basis points', () {
    const figure = AssistantFigure(
      id: 'f1', label: 'p', unit: FigureUnit.percent, op: 'percent_change',
      value: 3333,
      sources: [
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'a', raw: 3),
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'b', raw: 4),
      ],
    );
    expect(FigureVerifier.verify(figure), isTrue);
  });

  test('Success: a zero base is verified as undefined', () {
    const figure = AssistantFigure(
      id: 'f1', label: 'p', unit: FigureUnit.percent, op: 'percent_change',
      value: null, note: 'undefined_base',
      sources: [
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'a', raw: 0),
        FigureSource(callId: 'c', rpc: 'r', args: {}, path: 'b', raw: 4),
      ],
    );
    expect(FigureVerifier.verify(figure), isTrue);
  });
}
