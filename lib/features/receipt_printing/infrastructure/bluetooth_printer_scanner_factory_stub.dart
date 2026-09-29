import '../../settings/domain/repositories/parking_settings_repository.dart';
import 'bluetooth_printer_scanner_stub.dart';
import '../domain/repositories/receipt_printer.dart';

BluetoothPrinterScanner createBluetoothPrinterScanner(
  ParkingSettingsRepository settings,
) => UnsupportedBluetoothPrinterScanner();
