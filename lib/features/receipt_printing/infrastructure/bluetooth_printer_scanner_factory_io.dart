import '../../settings/domain/repositories/parking_settings_repository.dart';
import 'bluetooth_printer_scanner_io.dart';
import 'esc_pos_generator.dart';
import '../domain/repositories/receipt_printer.dart';

BluetoothPrinterScanner createBluetoothPrinterScanner(
  ParkingSettingsRepository settings,
) => BluetoothPrintScanner(const EscPosGenerator(), settings);
