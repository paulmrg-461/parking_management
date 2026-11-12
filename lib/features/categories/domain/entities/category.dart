import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({
    this.id,
    required this.name,
    this.capacity = 0,
    this.version = 0,
  });

  final int? id;
  final String name;

  /// 0 = unlimited.
  final int capacity;

  /// Row version from the server (`0` when unknown); offline edits send it so
  /// a concurrent change is a conflict, not an overwrite.
  final int version;

  @override
  List<Object?> get props => [id, name, capacity, version];
}
