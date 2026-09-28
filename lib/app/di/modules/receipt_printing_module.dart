import 'package:get_it/get_it.dart';

import '../../../features/receipt_printing/domain/repositories/receipt_printer.dart';
import '../../../features/receipt_printing/infrastructure/bluetooth_printer_scanner_factory.dart';
import '../../../features/receipt_printing/infrastructure/system_dialog_receipt_printer.dart';

void registerReceiptPrintingModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReceiptPrinter>(
      SystemDialogReceiptPrinter.new,
    )
    ..registerLazySingleton<BluetoothPrinterScanner>(
      createBluetoothPrinterScanner,
    );
}
