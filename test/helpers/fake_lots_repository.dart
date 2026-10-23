import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/lots/domain/entities/lot_member.dart';
import 'package:parking_management/features/lots/domain/entities/parking_lot.dart';
import 'package:parking_management/features/lots/domain/repositories/lots_repository.dart';

class FakeLotsRepository implements LotsRepository {
  FakeLotsRepository([List<ParkingLot> lots = const []]) : lots = List.of(lots);

  List<ParkingLot> lots;
  Failure? error;
  Failure? writeError;
  int? lastUpdated;

  @override
  Future<List<ParkingLot>> myLots() async =>
      error == null ? List.of(lots) : throw error!;

  @override
  Future<List<ParkingLot>> allLots() => myLots();

  @override
  Future<ParkingLot> create({
    required String code,
    required String name,
    String address = '',
    String timezone = 'America/Bogota',
  }) async {
    final failure = writeError;
    if (failure != null) {
      throw failure;
    }
    final lot = ParkingLot(
      id: lots.length + 1,
      code: code,
      name: name,
      address: address,
      role: 'admin',
    );
    lots = [...lots, lot];
    return lot;
  }

  @override
  Future<ParkingLot> update({
    required int id,
    String? name,
    String? address,
    String? timezone,
    bool? active,
  }) async {
    final failure = writeError;
    if (failure != null) {
      throw failure;
    }
    lastUpdated = id;
    final updated = lots.firstWhere((lot) => lot.id == id).copyWith(
      name: name,
      address: address,
      active: active,
    );
    lots = [for (final lot in lots) lot.id == id ? updated : lot];
    return updated;
  }

  List<LotMember> memberList = [];
  final List<String> memberWrites = [];

  @override
  Future<List<LotMember>> members(int lotId) async => memberList;

  @override
  Future<void> setMember({
    required int userId,
    required int lotId,
    required String role,
  }) async {
    final failure = writeError;
    if (failure != null) {
      throw failure;
    }
    memberWrites.add('$userId:$lotId:$role');
  }
}

ParkingLot sampleLot({
  int id = 1,
  String code = 'DEF',
  String name = 'Central',
  String role = 'admin',
}) => ParkingLot(id: id, code: code, name: name, role: role);
