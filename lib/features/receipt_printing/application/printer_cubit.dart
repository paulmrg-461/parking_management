import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/receipt/receipt_data.dart';
import '../../../core/receipt/receipt_labels.dart';
import '../domain/entities/bluetooth_printer.dart';
import '../domain/entities/print_outcome.dart';
import '../domain/repositories/receipt_printer.dart';
import '../../../core/state/resilient_cubit.dart';

class PrinterState extends Equatable {
  const PrinterState({
    this.printers = const [],
    this.scanning = false,
    this.printing = false,
    this.outcome,
  });

  final List<BluetoothPrinter> printers;
  final bool scanning;
  final bool printing;
  final PrintOutcome? outcome;

  PrinterState copyWith({
    List<BluetoothPrinter>? printers,
    bool? scanning,
    bool? printing,
    PrintOutcome? outcome,
  }) => PrinterState(
    printers: printers ?? this.printers,
    scanning: scanning ?? this.scanning,
    printing: printing ?? this.printing,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [printers, scanning, printing, outcome];
}

/// Bluetooth printer discovery and printing for the receipt print sheet.
class PrinterCubit extends ResilientCubit<PrinterState> {
  PrinterCubit(this._scanner) : super(const PrinterState());

  final BluetoothPrinterScanner _scanner;
  StreamSubscription<List<BluetoothPrinter>>? _resultsSub;
  StreamSubscription<bool>? _scanningSub;

  void startScan() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    _resultsSub = _scanner.results.listen(
      (printers) => emit(state.copyWith(printers: printers)),
    );
    _scanningSub = _scanner.isScanning.listen(
      (scanning) => emit(state.copyWith(scanning: scanning)),
    );
    _scanner.startScan();
  }

  void stopScan() {
    _scanner.stopScan();
  }

  Future<void> print(
    BluetoothPrinter printer,
    ReceiptData data,
    ReceiptLabels labels,
  ) async {
    if (state.printing) {
      return;
    }
    emit(
      PrinterState(
        printers: state.printers,
        scanning: state.scanning,
        printing: true,
      ),
    );
    final outcome = await _scanner.print(printer, data, labels);
    emit(
      PrinterState(
        printers: state.printers,
        scanning: state.scanning,
        printing: false,
        outcome: outcome,
      ),
    );
  }

  @override
  Future<void> close() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    return super.close();
  }
}
