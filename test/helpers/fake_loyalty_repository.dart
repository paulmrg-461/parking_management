import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_account.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_report.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_status.dart';
import 'package:parking_management/features/loyalty/domain/repositories/loyalty_repository.dart';

final sampleStatus = LoyaltyStatus(
  enabled: true,
  plate: 'ABC123',
  visits: 3,
  required: 5,
  nextVisit: 4,
  rewardCount: 0,
  redeemMode: LoyaltyRedeemMode.auto,
);

LoyaltyReport sampleReport({DateTime? start, DateTime? end}) => LoyaltyReport(
  startDate: start ?? DateTime(2026, 11, 1),
  endDate: end ?? DateTime(2026, 11, 30),
  enabled: true,
  members: 12,
  activeMembers: 7,
  counted: 30,
  skipped: 4,
  reversed: 1,
  skippedByReason: const [SkipCount(reason: 'same_day', count: 3)],
  earned: 6,
  redeemed: 4,
  available: 2,
  discountGiven: 24000,
  topPlates: const [
    LoyaltyTopPlate(plate: 'ABC123', counted: 9, redeemed: 1, discount: 6000),
  ],
);

class FakeLoyaltyRepository implements LoyaltyRepository {
  FakeLoyaltyRepository({
    LoyaltyStatus? statusResult,
    this.settings = const LoyaltySettings(enabled: true, visitsRequired: 5),
    List<LoyaltyAccount>? accounts,
    LoyaltyReport? report,
  }) : statusResult = statusResult ?? sampleStatus,
       accountRows = accounts ??
           const [
             LoyaltyAccount(
               plate: 'ABC123',
               progress: 3,
               earnedTotal: 2,
               redeemedTotal: 1,
             ),
           ],
       reportResult = report ?? sampleReport();

  LoyaltyStatus statusResult;
  LoyaltySettings settings;
  List<LoyaltyAccount> accountRows;
  LoyaltyReport reportResult;
  Failure? loadError;
  Failure? statusError;
  Failure? writeError;
  int statusCalls = 0;
  int settingsSaves = 0;
  int accountsCalls = 0;
  int adjustCalls = 0;
  int reportCalls = 0;
  String? lastSearch;
  String? lastPlate;
  final List<LoyaltyChoice> choices = [];
  ({String plate, int delta, String reason})? lastAdjust;
  DateTime? lastReportStart;
  DateTime? lastReportEnd;

  void _throwIfWriteFails() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<LoyaltyStatus> status(String plate) async {
    statusCalls++;
    lastPlate = plate;
    final error = statusError;
    if (error != null) {
      throw error;
    }
    return statusResult;
  }

  @override
  Future<LoyaltySettings> loadSettings() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return settings;
  }

  @override
  Future<LoyaltySettings> saveSettings(LoyaltySettings next) async {
    _throwIfWriteFails();
    settingsSaves++;
    settings = next;
    return next;
  }

  @override
  Future<void> choose({
    required int sessionId,
    required LoyaltyChoice choice,
  }) async {
    _throwIfWriteFails();
    choices.add(choice);
  }

  @override
  Future<List<LoyaltyAccount>> accounts({String? search}) async {
    accountsCalls++;
    lastSearch = search;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return List.of(accountRows);
  }

  @override
  Future<LoyaltyAdjustResult> adjust({
    required String plate,
    required int delta,
    required String reason,
  }) async {
    _throwIfWriteFails();
    adjustCalls++;
    lastAdjust = (plate: plate, delta: delta, reason: reason);
    return LoyaltyAdjustResult(
      plate: plate,
      progress: 4,
      required: settings.visitsRequired,
      delta: delta,
    );
  }

  @override
  Future<LoyaltyReport> report({
    required DateTime start,
    required DateTime end,
  }) async {
    reportCalls++;
    lastReportStart = start;
    lastReportEnd = end;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return sampleReport(start: start, end: end);
  }
}
