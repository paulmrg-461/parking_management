import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

import '../../../core/receipt/receipt_data.dart';
import '../domain/entities/bluetooth_printer.dart';
import '../domain/entities/print_outcome.dart';
import '../domain/repositories/receipt_printer.dart';
import 'receipt_line_builder.dart';

/// Android/iOS: discovers and prints to classic-Bluetooth thermal printers
/// over SPP using `bluetooth_print`, building ESC/POS lines with
/// [ReceiptLineBuilder].
class BluetoothPrintScanner implements BluetoothPrinterScanner {
  BluetoothPrintScanner(this._builder);

  final ReceiptLineBuilder _builder;
  final BluetoothPrint _bluetooth = BluetoothPrint.instance;
  final Map<String, BluetoothDevice> _byAddress = {};

  @override
  Stream<List<BluetoothPrinter>> get results => _bluetooth.scanResults.map(
    (devices) {
      _byAddress.clear();
      final printers = <BluetoothPrinter>[];
      for (final device in devices) {
        if (device.name != null && device.address != null) {
          _byAddress[device.address!] = device;
          printers.add(
            BluetoothPrinter(name: device.name!, address: device.address!),
          );
        }
      }
      return printers;
    },
  );

  @override
  Stream<bool> get isScanning => _bluetooth.isScanning;

  @override
  Future<void> startScan() async {
    await _bluetooth.startScan(timeout: const Duration(seconds: 10));
  }

  @override
  Future<void> stopScan() async {
    await _bluetooth.stopScan();
  }

  @override
  Future<PrintOutcome> print(BluetoothPrinter printer, ReceiptData data) async {
    final device = _byAddress[printer.address];
    if (device == null) {
      return PrintOutcome.printerNotSelected;
    }
    try {
      await _bluetooth.connect(device);
      await _bluetooth.printReceipt({}, _builder.build(data));
      return PrintOutcome.success;
    } catch (_) {
      return PrintOutcome.failed;
    }
  }
}
