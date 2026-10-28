import 'package:equatable/equatable.dart';

import '../../../check_out/domain/entities/slot_board.dart';

/// One physical bay on the site's map. [row]/[col] are 0-based grid positions
/// the admin arranges by dragging; [active] false means out of service.
class ParkingSpot extends Equatable {
  const ParkingSpot({
    required this.id,
    required this.code,
    required this.group,
    required this.row,
    required this.col,
    this.active = true,
  });

  final int id;
  final String code;
  final SlotGroup group;
  final int row;
  final int col;
  final bool active;

  factory ParkingSpot.fromJson(Map<String, dynamic> json) => ParkingSpot(
    id: (json['id'] as num).toInt(),
    code: json['code'] as String,
    group: SlotGroup.fromWire(json['group']),
    row: (json['row'] as num?)?.toInt() ?? 0,
    col: (json['col'] as num?)?.toInt() ?? 0,
    active: json['active'] != false,
  );

  ParkingSpot copyWith({
    String? code,
    SlotGroup? group,
    int? row,
    int? col,
    bool? active,
  }) => ParkingSpot(
    id: id,
    code: code ?? this.code,
    group: group ?? this.group,
    row: row ?? this.row,
    col: col ?? this.col,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'group': group.name,
    'row': row,
    'col': col,
    'active': active,
  };

  @override
  List<Object?> get props => [id, code, group, row, col, active];
}
