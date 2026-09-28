import 'dart:async';

import '../../../core/receipt/receipt_data.dart';
import '../domain/entities/bluetooth_printer.dart';
import '../domain/entities/print_outcome.dart';
import '../domain/repositories/receipt_printer.dart';

/// Web/desktop: classic Bluetooth is unavailable, so scanning is always
/// empty and printing is unsupported (the UI hides the Bluetooth option).
class UnsupportedBluetoothPrinterScanner implements BluetoothPrinterScanner {
  final StreamController<List<BluetoothPrinter>> _results =
      StreamController<List<BluetoothPrinter>>.broadcast();
  final StreamController<bool> _scanning = StreamController<bool>.broadcast();

  @override
  Stream<List<BluetoothPrinter>> get results => _results.stream;

  @override
  Stream<bool> get isScanning => _scanning.stream;

  @override
  Future<void> startScan() async {
    _results.add(const []);
    _scanning.add(false);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<PrintOutcome> print(BluetoothPrinter printer, ReceiptData data) async =>
      PrintOutcome.failed;
}
