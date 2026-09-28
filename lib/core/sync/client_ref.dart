import 'dart:math';

final Random _random = Random.secure();

/// 2^32 as a literal: `1 << 32` is 0 when compiled to JavaScript (shift
/// counts are taken mod 32), which would make `nextInt` throw on web.
const _uint32Range = 0x100000000;

/// A client-generated unique reference for a queued mutation. Used as the
/// pending-photo folder name and as the `Idempotency-Key` header on replay,
/// so it must be unguessable and stable for the life of the queue entry.
String newClientRef() {
  final suffix = List.generate(
    4,
    (_) => _random.nextInt(_uint32Range).toRadixString(16).padLeft(8, '0'),
  ).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
}
