import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/shifts/domain/entities/shift_summary.dart';
import 'package:parking_management/features/shifts/domain/repositories/shift_repository.dart';

class FakeShiftRepository implements ShiftRepository {
  FakeShiftRepository({this.currentShift, this.historyShifts = const []});

  ShiftSummary? currentShift;
  List<ShiftSummary> historyShifts;
  Failure? error;

  @override
  Future<ShiftSummary?> current() async {
    _throwIfNeeded();
    return currentShift;
  }

  @override
  Future<ShiftSummary> open(int openingFloat) async {
    _throwIfNeeded();
    currentShift = sampleShift(openingFloat: openingFloat);
    return currentShift!;
  }

  @override
  Future<ShiftSummary> close({
    required int countedCash,
    String? notes,
  }) async {
    _throwIfNeeded();
    final closed = sampleShift(
      openingFloat: currentShift?.openingFloat ?? 0,
      countedCash: countedCash,
      difference: countedCash - (currentShift?.expectedCash ?? 0),
      closed: true,
      notes: notes,
    );
    currentShift = null;
    return closed;
  }

  @override
  Future<ShiftSummary> addMovement({
    required String type,
    required int amount,
    required String reason,
  }) async {
    _throwIfNeeded();
    final shift = currentShift!;
    currentShift = sampleShift(
      openingFloat: shift.openingFloat,
      withdrawals: type == 'withdrawal' ? amount : 0,
      deposits: type == 'deposit' ? amount : 0,
    );
    return currentShift!;
  }

  @override
  Future<ShiftSummary> adjust({
    required int shiftId,
    required int countedCash,
    required String reason,
  }) async {
    _throwIfNeeded();
    final closed = sampleShift(
      id: shiftId,
      countedCash: countedCash,
      difference: countedCash - 15000,
      closed: true,
      notes: reason,
    );
    historyShifts = [closed];
    return closed;
  }

  @override
  Future<List<ShiftSummary>> history({int limit = 20}) async {
    _throwIfNeeded();
    return historyShifts;
  }

  void _throwIfNeeded() {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}

ShiftSummary sampleShift({
  int id = 1,
  int openingFloat = 10000,
  int countedCash = 0,
  int difference = 0,
  bool closed = false,
  String? notes,
  int withdrawals = 0,
  int deposits = 0,
}) => ShiftSummary(
  id: id,
  operatorId: 1,
  openedAt: DateTime.utc(2026, 10, 23, 8),
  closedAt: closed ? DateTime.utc(2026, 10, 23, 18) : null,
  openingFloat: openingFloat,
  countedCash: closed ? countedCash : null,
  expectedCash: openingFloat + 5000 + deposits - withdrawals,
  difference: closed ? difference : null,
  notes: notes,
  sessionCount: 1,
  revenue: 5000,
  cashSales: 5000,
  discounts: 1000,
  withdrawals: withdrawals,
  deposits: deposits,
);
