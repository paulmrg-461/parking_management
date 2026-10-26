import 'package:get_it/get_it.dart';

import '../../../features/receipt_printing/domain/repositories/receipt_printer.dart';
import '../../../features/receipt_printing/infrastructure/bluetooth_printer_scanner_factory.dart';
import '../../../features/receipt_printing/infrastructure/system_dialog_receipt_printer.dart';
import '../../../features/settings/domain/repositories/parking_settings_repository.dart';

void registerReceiptPrintingModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReceiptPrinter>(
      () => SystemDialogReceiptPrinter(sl<ParkingSettingsRepository>()),
    )
    ..registerLazySingleton<BluetoothPrinterScanner>(
      () => createBluetoothPrinterScanner(sl<ParkingSettingsRepository>()),
    );
}
