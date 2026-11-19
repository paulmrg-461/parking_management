import 'package:equatable/equatable.dart';

/// A field both writers changed to different values: only a human can decide.
class FieldConflict extends Equatable {
  const FieldConflict({
    required this.field,
    required this.base,
    required this.mine,
    required this.theirs,
  });

  final String field;
  final Object? base;
  final Object? mine;
  final Object? theirs;

  @override
  List<Object?> get props => [field, base, mine, theirs];
}

/// What can be sent without asking and what needs a decision.
class MergePlan extends Equatable {
  const MergePlan({this.autoApply = const {}, this.conflicts = const []});

  /// Fields only this writer changed since [base]: safe to send.
  final Map<String, Object?> autoApply;

  /// Fields both sides changed to different values.
  final List<FieldConflict> conflicts;

  /// The server already has every change this writer wanted.
  bool get serverAlreadyHasMine => autoApply.isEmpty && conflicts.isEmpty;

  @override
  List<Object?> get props => [autoApply, conflicts];
}

/// Three-way merge of a queued patch against the row the server has now.
///
/// [mine] carries only the fields the user changed; [base] is the row as it was
/// when they started editing (`null` when it was never cached, which makes
/// every differing field a conflict). Fields only [theirs] changed are left
/// untouched.
MergePlan planMerge({
  required Map<String, Object?>? base,
  required Map<String, Object?> mine,
  required Map<String, Object?> theirs,
}) {
  final autoApply = <String, Object?>{};
  final conflicts = <FieldConflict>[];
  for (final entry in mine.entries) {
    final field = entry.key;
    final mineValue = _normalize(entry.value);
    final theirValue = _normalize(theirs[field]);
    if (_same(mineValue, theirValue)) {
      // The server already has this value: nothing to send for it.
      continue;
    }
    final baseValue = base == null ? null : _normalize(base[field]);
    if (base != null && _same(theirValue, baseValue)) {
      // The other writer did not touch this field: ours applies cleanly.
      autoApply[field] = entry.value;
      continue;
    }
    conflicts.add(
      FieldConflict(
        field: field,
        base: baseValue,
        mine: mineValue,
        theirs: theirValue,
      ),
    );
  }
  return MergePlan(autoApply: autoApply, conflicts: conflicts);
}

/// Text columns store `''` where the client may send `null`; comparing them
/// literally would report a conflict for the same value.
Object? _normalize(Object? value) {
  if (value is String && value.isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return value;
}

bool _same(Object? a, Object? b) {
  if (a is num && b is num) {
    return a.toInt() == b.toInt();
  }
  return a == b;
}
