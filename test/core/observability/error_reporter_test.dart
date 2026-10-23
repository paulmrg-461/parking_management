import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/observability/client_error_sink.dart';
import 'package:parking_management/core/observability/error_reporter.dart';

class _FakeSink implements ClientErrorSink {
  final List<Map<String, Object?>> sent = [];
  bool failing = false;

  @override
  Future<void> send({
    required String platform,
    required String message,
    String? stack,
    Map<String, Object?> context = const {},
  }) async {
    if (failing) {
      throw StateError('transport down');
    }
    sent.add({
      'platform': platform,
      'message': message,
      'stack': stack,
      'context': context,
    });
  }
}

void main() {
  late _FakeSink sink;
  late DateTime now;

  ErrorReporter reporter() => ErrorReporter(
    sink,
    clock: () => now,
    minInterval: const Duration(seconds: 30),
    enabled: true,
  );

  setUp(() {
    sink = _FakeSink();
    now = DateTime.utc(2026, 10, 23, 12);
  });

  test('Success: an uncaught error is reported once with its context', () async {
    final reporterInstance = reporter();

    await reporterInstance.report(
      StateError('boom'),
      StackTrace.current,
      context: {'kind': 'uncaught'},
    );

    expect(sink.sent, hasLength(1));
    expect(sink.sent.single['message'], contains('boom'));
    expect(sink.sent.single['context'], {'kind': 'uncaught'});
  });

  test('Security: repeated identical errors are throttled', () async {
    final reporterInstance = reporter();

    await reporterInstance.report(StateError('boom'), StackTrace.current);
    await reporterInstance.report(StateError('boom'), StackTrace.current);
    expect(sink.sent, hasLength(1));

    now = now.add(const Duration(seconds: 31));
    await reporterInstance.report(StateError('boom'), StackTrace.current);
    expect(sink.sent, hasLength(2));
  });

  test('Failure: a broken transport never propagates', () async {
    sink.failing = true;

    await expectLater(
      reporter().report(StateError('boom'), StackTrace.current),
      completes,
    );
  });

  test('Success: the payload stays bounded', () async {
    await reporter().report(StateError('x' * 5000), StackTrace.current);

    expect((sink.sent.single['message']! as String).length, 2000);
  });

  test('Security: reporting is disabled outside production builds by default',
      () async {
    final disabled = ErrorReporter(sink, clock: () => now, enabled: false);

    await disabled.report(StateError('boom'), StackTrace.current);

    expect(sink.sent, isEmpty);
  });
}
