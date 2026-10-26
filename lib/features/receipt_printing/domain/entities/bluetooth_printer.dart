import 'package:equatable/equatable.dart';

/// A discovered Bluetooth thermal printer.
class BluetoothPrinter extends Equatable {
  const BluetoothPrinter({required this.name, required this.address});

  final String name;
  final String address;

  @override
  List<Object?> get props => [name, address];
}
