import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/receipt_data.dart';
import 'package:parking_management/features/receipt_printing/application/printer_cubit.dart';
import 'package:parking_management/features/receipt_printing/domain/entities/bluetooth_printer.dart';
import 'package:parking_management/features/receipt_printing/domain/entities/print_outcome.dart';
import 'package:parking_management/features/receipt_printing/domain/repositories/receipt_printer.dart';

class _FakeScanner implements BluetoothPrinterScanner {
  final _results = StreamController<List<BluetoothPrinter>>.broadcast();
  final _scanning = StreamController<bool>.broadcast();

  PrintOutcome outcome = PrintOutcome.success;
  BluetoothPrinter? lastPrinted;

  @override
  Stream<List<BluetoothPrinter>> get results => _results.stream;

  @override
  Stream<bool> get isScanning => _scanning.stream;

  @override
  Future<void> startScan() async {
    _scanning.add(true);
    _results.add(const [
      BluetoothPrinter(name: 'EPSON', address: 'AA:BB:CC'),
    ]);
    _scanning.add(false);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<PrintOutcome> print(BluetoothPrinter printer, ReceiptData data) async {
    lastPrinted = printer;
    return outcome;
  }
}

ReceiptData _data() => ReceiptData(
  kind: ReceiptKind.checkIn,
  plate: 'ABC123',
  entryTime: DateTime(2026, 1, 1),
);

void main() {
  test('startScan surfaces discovered printers', () async {
    final cubit = PrinterCubit(_FakeScanner());
    final states = <PrinterState>[];
    final sub = cubit.stream.listen(states.add);

    cubit.startScan();
    await Future<void>.delayed(Duration.zero);

    expect(
      states.any((s) => s.printers.any((p) => p.name == 'EPSON')),
      isTrue,
    );
    await sub.cancel();
    await cubit.close();
  });

  test('print sends the selected printer and records the outcome', () async {
    final scanner = _FakeScanner();
    final cubit = PrinterCubit(scanner);
    const printer = BluetoothPrinter(name: 'EPSON', address: 'AA:BB:CC');

    await cubit.print(printer, _data());

    expect(scanner.lastPrinted?.address, 'AA:BB:CC');
    expect(cubit.state.outcome, PrintOutcome.success);
    await cubit.close();
  });

  test('a failed print records a non-success outcome', () async {
    final scanner = _FakeScanner()..outcome = PrintOutcome.timeout;
    final cubit = PrinterCubit(scanner);

    await cubit.print(
      const BluetoothPrinter(name: 'EPSON', address: 'AA:BB:CC'),
      _data(),
    );

    expect(cubit.state.outcome, PrintOutcome.timeout);
    expect(cubit.state.printing, isFalse);
    await cubit.close();
  });
}
