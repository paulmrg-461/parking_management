import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';

void main() {
  group('PendingMutation serialization', () {
    test('Success: round-trips enums (as .name) and retry metadata', () {
      final original = PendingMutation(
        entityType: MutationEntity.checkOut,
        operation: MutationOperation.close,
        entityId: 5,
        payloadJson: '{"client_ref":"r1"}',
        enqueuedAt: DateTime.utc(2026, 1, 1),
        attempts: 2,
        lastError: 'boom',
        nextAttemptAt: DateTime.utc(2026, 1, 1, 0, 0, 4),
      );

      final json = original.toJson();
      final parsed = PendingMutation.fromJson(json);

      expect(json['entityType'], 'checkOut');
      expect(json['operation'], 'close');
      expect(parsed, original);
    });

    test(
      'Success: parses legacy string-typed entries with default metadata',
      () {
        final legacy = PendingMutation.fromJson({
          'entityType': 'vehicle',
          'operation': 'update',
          'entityId': 1,
          'payloadJson': '{"color":"red"}',
          'enqueuedAt': '2026-01-01T00:00:00.000Z',
        });

        expect(legacy.entityType, MutationEntity.vehicle);
        expect(legacy.operation, MutationOperation.update);
        expect(legacy.attempts, 0);
        expect(legacy.lastError, isNull);
        expect(legacy.nextAttemptAt, isNull);
        expect(legacy.deadLettered, isFalse);
      },
    );

    test(
      'Failure: recordFailure increments attempts and keeps the payload',
      () {
        final base = PendingMutation(
          entityType: MutationEntity.tariff,
          operation: MutationOperation.delete,
          entityId: 3,
          payloadJson: null,
          enqueuedAt: DateTime.utc(2026, 1, 1),
        );

        final failed = base.recordFailure('409 conflict', deadLettered: true);

        expect(failed.attempts, 1);
        expect(failed.lastError, '409 conflict');
        expect(failed.deadLettered, isTrue);
        expect(failed.entityId, 3);
      },
    );

    test('Security: unknown entity/operation names are rejected', () {
      expect(
        () => PendingMutation.fromJson({
          'entityType': 'user',
          'operation': 'update',
          'entityId': 1,
          'payloadJson': null,
          'enqueuedAt': '2026-01-01T00:00:00.000Z',
        }),
        throwsFormatException,
      );
    });
  });
}
