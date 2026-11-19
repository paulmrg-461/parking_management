import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_progress.dart';
import 'package:parking_management/features/report_assistant/infrastructure/sse_event_parser.dart';

Stream<List<int>> chunks(List<String> values) async* {
  for (final value in values) {
    yield utf8.encode(value);
  }
}

void main() {
  test('parses events split across chunks and ignores keepalives', () async {
    final events = await parseAssistantSse(chunks([
      ': keepalive\n\nevent: started\ndata: {"request_id": 7}\n\nevent: too',
      'l\ndata: {"call_id":"c1","tool":"get_revenue_report","state":"done","ms":5}\n\n',
    ])).toList();

    expect(events.first, isA<AssistantStarted>());
    expect(events.last, isA<AssistantToolEvent>());
    expect(
      (events.last as AssistantToolEvent).progress.state,
      ToolState.done,
    );
  });

  test('handles CRLF and malformed JSON', () async {
    final events = await parseAssistantSse(chunks([
      'event: answer\r\ndata: not-json\r\n\r\n',
    ])).toList();
    expect(events.single, isA<AssistantMalformed>());
  });

  test('parses answer and done with the remaining budget', () async {
    final events = await parseAssistantSse(chunks([
      'event: answer\ndata: {"status":"answered","headline":"x","figures":[]}\n\n',
      'event: done\ndata: {"iterations":1,"tool_calls":0,"remaining":{"requests":99,"tokens":9}}\n\n',
    ])).toList();

    expect(events.first.runtimeType.toString(), 'AssistantAnswered');
    expect((events.last as AssistantDone).remainingRequests, 99);
  });
}
