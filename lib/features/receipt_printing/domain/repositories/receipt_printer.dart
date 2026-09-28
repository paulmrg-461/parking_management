import '../../../../core/receipt/receipt_data.dart';
import '../entities/bluetooth_printer.dart';
import '../entities/print_outcome.dart';

/// Prints a receipt via the OS print/share dialog (PDF), available on every
/// platform (Android, web, desktop).
abstract class ReceiptPrinter {
  Future<void> printPdf(ReceiptData data);
}

/// Discovers and prints to Bluetooth thermal printers (Android only).
///
/// Implementations on platforms without classic Bluetooth expose an empty
/// scan stream and an "unsupported" result; the UI hides the option there.
abstract class BluetoothPrinterScanner {
  Stream<List<BluetoothPrinter>> get results;

  Stream<bool> get isScanning;

  Future<void> startScan();

  Future<void> stopScan();

  Future<PrintOutcome> print(BluetoothPrinter printer, ReceiptData data);
}
