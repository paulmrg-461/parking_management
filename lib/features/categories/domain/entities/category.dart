import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({this.id, required this.name, this.capacity = 0});

  final int? id;
  final String name;

  /// 0 = unlimited.
  final int capacity;

  @override
  List<Object?> get props => [id, name, capacity];
}
