import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';

import '../../../core/receipt/receipt_data.dart';
import '../domain/entities/bluetooth_printer.dart';
import '../domain/entities/print_outcome.dart';
import '../domain/repositories/receipt_printer.dart';
import 'esc_pos_generator.dart';

/// Android/iOS: discovers and prints to classic-Bluetooth thermal printers
/// over SPP using `bluetooth_print_plus`, sending the raw ESC/POS bytes built
/// by [EscPosGenerator].
class BluetoothPrintScanner implements BluetoothPrinterScanner {
  BluetoothPrintScanner(this._generator);

  static const _connectTimeout = Duration(seconds: 10);

  final EscPosGenerator _generator;
  final Map<String, BluetoothDevice> _byAddress = {};

  @override
  Stream<List<BluetoothPrinter>> get results =>
      BluetoothPrintPlus.scanResults.map((devices) {
        _byAddress.clear();
        final printers = <BluetoothPrinter>[];
        for (final device in devices) {
          if (device.name.isNotEmpty && device.address.isNotEmpty) {
            _byAddress[device.address] = device;
            printers.add(
              BluetoothPrinter(name: device.name, address: device.address),
            );
          }
        }
        return printers;
      });

  @override
  Stream<bool> get isScanning => BluetoothPrintPlus.isScanning;

  @override
  Future<void> startScan() => BluetoothPrintPlus.startScan(
    timeout: const Duration(seconds: 10),
  );

  @override
  Future<void> stopScan() => BluetoothPrintPlus.stopScan();

  @override
  Future<PrintOutcome> print(BluetoothPrinter printer, ReceiptData data) async {
    final device = _byAddress[printer.address];
    if (device == null) {
      return PrintOutcome.printerNotSelected;
    }
    try {
      await _reconnectTo(device);
      await BluetoothPrintPlus.write(
        Uint8List.fromList(_generator.build(data)),
      );
      return PrintOutcome.success;
    } on TimeoutException {
      return PrintOutcome.timeout;
    } catch (_) {
      return PrintOutcome.failed;
    }
  }

  /// Connects to [device], first dropping any stale connection so the write
  /// never races against a link to a previously printed printer.
  Future<void> _reconnectTo(BluetoothDevice device) async {
    if (BluetoothPrintPlus.isConnected) {
      await BluetoothPrintPlus.disconnect();
      await BluetoothPrintPlus.connectState
          .firstWhere((state) => state == ConnectState.disconnected)
          .timeout(_connectTimeout);
    }
    await BluetoothPrintPlus.connect(device);
    await BluetoothPrintPlus.connectState
        .firstWhere((state) => state == ConnectState.connected)
        .timeout(_connectTimeout);
  }
}
