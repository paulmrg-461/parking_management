import 'bluetooth_printer_scanner_io.dart';
import 'receipt_line_builder.dart';
import '../domain/repositories/receipt_printer.dart';

BluetoothPrinterScanner createBluetoothPrinterScanner() =>
    BluetoothPrintScanner(const ReceiptLineBuilder());
