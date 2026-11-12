import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/conflict/three_way_merge.dart';

void main() {
  test('Success: fields only I changed apply automatically', () {
    final plan = planMerge(
      base: {'color': 'red', 'brand': 'Kia'},
      mine: {'color': 'blue'},
      theirs: {'color': 'red', 'brand': 'Kia'},
    );

    expect(plan.autoApply, {'color': 'blue'});
    expect(plan.conflicts, isEmpty);
    expect(plan.serverAlreadyHasMine, isFalse);
  });

  test('Failure: the same field changed differently conflicts', () {
    final plan = planMerge(
      base: {'color': 'red'},
      mine: {'color': 'blue'},
      theirs: {'color': 'green'},
    );

    expect(plan.autoApply, isEmpty);
    expect(plan.conflicts.single.field, 'color');
    expect(plan.conflicts.single.mine, 'blue');
    expect(plan.conflicts.single.theirs, 'green');
  });

  test('Success: a field the server already has is dropped', () {
    final plan = planMerge(
      base: {'color': 'red'},
      mine: {'color': 'blue'},
      theirs: {'color': 'blue'},
    );

    expect(plan.autoApply, isEmpty);
    expect(plan.conflicts, isEmpty);
    expect(plan.serverAlreadyHasMine, isTrue);
  });

  test(
    'Failure: an unknown base treats every differing field as a conflict',
    () {
      final plan = planMerge(
        base: null,
        mine: {'color': 'blue'},
        theirs: {'color': 'red'},
      );

      expect(plan.conflicts.single.field, 'color');
      // Equal values still drop even without a base.
      expect(
        planMerge(
          base: null,
          mine: {'color': 'red'},
          theirs: {'color': 'red'},
        ).conflicts,
        isEmpty,
      );
    },
  );

  test('Success: null and an empty string are the same text value', () {
    final plan = planMerge(
      base: {'notes': null},
      mine: {'notes': ''},
      theirs: {'notes': null},
    );

    expect(plan.serverAlreadyHasMine, isTrue);
  });

  test('Success: numbers compare numerically', () {
    final plan = planMerge(
      base: {'capacity': 10},
      mine: {'capacity': 10.0},
      theirs: {'capacity': 10},
    );

    expect(plan.serverAlreadyHasMine, isTrue);
  });

  test('Success: fields only the server changed are not in the plan', () {
    final plan = planMerge(
      base: {'color': 'red', 'brand': 'Kia'},
      mine: {'color': 'blue'},
      theirs: {'color': 'red', 'brand': 'Mazda'},
    );

    expect(plan.autoApply.keys, ['color']);
    expect(plan.autoApply.containsKey('brand'), isFalse);
  });
}
