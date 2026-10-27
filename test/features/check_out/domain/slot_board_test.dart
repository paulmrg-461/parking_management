import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';

void main() {
  test('Success: parses capacities, sessions and holds', () {
    final board = SlotBoard.fromJson(const {
      'car_capacity': 20,
      'moto_capacity': 60,
      'sessions': [
        {
          'session_id': 3,
          'plate': 'ABC123',
          'entry_time': '2026-10-27T13:00:00+00:00',
          'left_keys': true,
          'photo_count': 2,
          'has_pass': true,
          'group': 'car',
        },
        {
          'session_id': 4,
          'plate': 'MOT01',
          'entry_time': '2026-10-27T14:00:00+00:00',
          'group': 'moto',
        },
      ],
      'holds': [
        {
          'plate': 'HOLD01',
          'reserved_until': '2026-10-27T18:00:00+00:00',
          'group': 'car',
        },
      ],
    });

    expect(board.carCapacity, 20);
    expect(board.motoCapacity, 60);
    expect(board.sessionsIn(SlotGroup.car).single.plate, 'ABC123');
    expect(board.sessionsIn(SlotGroup.car).single.leftKeys, isTrue);
    expect(board.sessionsIn(SlotGroup.moto).single.plate, 'MOT01');
    expect(board.holdsIn(SlotGroup.car).single.plate, 'HOLD01');
  });

  test('Failure: an empty payload is an empty board', () {
    final board = SlotBoard.fromJson(const {});

    expect(board.isEmpty, isTrue);
    expect(board.sessions, isEmpty);
    expect(board.holds, isEmpty);
  });

  test('Security: an unknown group falls back to heavy, never to a car', () {
    final board = SlotBoard.fromJson(const {
      'car_capacity': 10,
      'sessions': [
        {
          'session_id': 5,
          'plate': 'TRK999',
          'entry_time': '2026-10-27T13:00:00+00:00',
          'group': 'spaceship',
        },
      ],
    });

    expect(board.sessionsIn(SlotGroup.car), isEmpty);
    expect(board.sessionsIn(SlotGroup.heavy).single.plate, 'TRK999');
  });
}
