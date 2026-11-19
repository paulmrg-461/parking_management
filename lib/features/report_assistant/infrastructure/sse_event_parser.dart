import 'dart:convert';

import '../domain/entities/assistant_answer.dart';
import '../domain/entities/assistant_progress.dart';

/// Parses the `report-assistant` event stream. Comments (`: keepalive`) are
/// ignored, CRLF is accepted, and a malformed JSON event becomes
/// [AssistantMalformed] so the UI can fail the turn instead of crashing.
Stream<AssistantEvent> parseAssistantSse(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final chunk in bytes) {
    buffer += utf8.decode(chunk, allowMalformed: true);
    buffer = buffer.replaceAll('\r\n', '\n');
    while (buffer.contains('\n\n')) {
      final index = buffer.indexOf('\n\n');
      final raw = buffer.substring(0, index);
      buffer = buffer.substring(index + 2);
      final event = _parseBlock(raw);
      if (event != null) {
        yield event;
      }
    }
  }
  if (buffer.trim().isNotEmpty) {
    final event = _parseBlock(buffer);
    if (event != null) {
      yield event;
    }
  }
}

AssistantEvent? _parseBlock(String raw) {
  var name = '';
  final data = StringBuffer();
  for (final line in raw.split('\n')) {
    if (line.startsWith(':')) {
      continue;
    }
    if (line.startsWith('event:')) {
      name = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.write(line.substring(5).trim());
    }
  }
  if (name.isEmpty || data.isEmpty) {
    return null;
  }
  Map<String, dynamic> json;
  try {
    final decoded = jsonDecode(data.toString());
    if (decoded is! Map) {
      return const AssistantMalformed();
    }
    json = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return const AssistantMalformed();
  }
  switch (name) {
    case 'started':
      return AssistantStarted((json['request_id'] as num?)?.toInt() ?? 0);
    case 'tool':
      final state = switch (json['state']) {
        'done' => ToolState.done,
        'error' => ToolState.error,
        _ => ToolState.running,
      };
      return AssistantToolEvent(
        ToolProgress(
          callId: json['call_id'] as String? ?? '',
          tool: json['tool'] as String? ?? '',
          rpc: json['rpc'] as String? ?? '',
          args: {
            for (final entry in (json['args'] as Map? ?? const {}).entries)
              entry.key.toString(): entry.value.toString(),
          },
          state: state,
          ms: (json['ms'] as num?)?.toInt(),
          code: json['code'] as String?,
        ),
      );
    case 'answer':
      return AssistantAnswered(AssistantAnswer.fromJson(json));
    case 'error':
      return AssistantError(json['code'] as String? ?? 'AiUpstreamError');
    case 'done':
      final remaining = json['remaining'];
      final remainingMap = remaining is Map
          ? Map<String, dynamic>.from(remaining)
          : const <String, dynamic>{};
      return AssistantDone(
        iterations: (json['iterations'] as num?)?.toInt() ?? 0,
        toolCalls: (json['tool_calls'] as num?)?.toInt() ?? 0,
        remainingRequests: (remainingMap['requests'] as num?)?.toInt(),
        remainingTokens: (remainingMap['tokens'] as num?)?.toInt(),
      );
    default:
      return null;
  }
}
