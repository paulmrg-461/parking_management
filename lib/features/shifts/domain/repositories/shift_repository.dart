import '../entities/shift_summary.dart';

abstract class ShiftRepository {
  Future<ShiftSummary?> current();

  Future<ShiftSummary> open(int openingFloat);

  Future<ShiftSummary> close({required int countedCash, String? notes});

  Future<ShiftSummary> addMovement({
    required String type,
    required int amount,
    required String reason,
  });

  Future<List<ShiftSummary>> history({
    int limit = 20,
    DateTime? from,
    DateTime? to,
  });

  Future<ShiftSummary> adjust({
    required int shiftId,
    required int countedCash,
    required String reason,
  });
}
