// Picks the Bluetooth printer scanner at compile time so the web bundle
// never references `bluetooth_print` (a mobile-only plugin).
export 'bluetooth_printer_scanner_factory_stub.dart'
    if (dart.library.io) 'bluetooth_printer_scanner_factory_io.dart';
