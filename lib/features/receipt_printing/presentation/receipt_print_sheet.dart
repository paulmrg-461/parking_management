import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/receipt/receipt_data.dart';
import '../../../../core/widgets/submission_feedback.dart';
import '../application/printer_cubit.dart';
import '../domain/entities/print_outcome.dart';
import '../domain/repositories/receipt_printer.dart';

/// Opens the print sheet for [data], resolving the printer adapters from the
/// composition root. Called from the receipt's "Imprimir" action.
Future<void> showReceiptPrintSheet(BuildContext context, ReceiptData data) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ReceiptPrintSheet(
      data: data,
      printer: serviceLocator<ReceiptPrinter>(),
      scanner: serviceLocator<BluetoothPrinterScanner>(),
    ),
  );
}

/// Offers a system PDF print and Bluetooth printer discovery/printing.
class ReceiptPrintSheet extends StatelessWidget {
  const ReceiptPrintSheet({
    super.key,
    required this.data,
    required this.printer,
    required this.scanner,
  });

  final ReceiptData data;
  final ReceiptPrinter printer;
  final BluetoothPrinterScanner scanner;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrinterCubit>(
      create: (_) => PrinterCubit(scanner),
      child: _ReceiptPrintSheetContent(data: data, printer: printer),
    );
  }
}

class _ReceiptPrintSheetContent extends StatelessWidget {
  const _ReceiptPrintSheetContent({required this.data, required this.printer});

  final ReceiptData data;
  final ReceiptPrinter printer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.printReceipt, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.print),
              label: Text(l10n.printSystem),
              onPressed: () async {
                await printer.printPdf(data);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: 24),
            Text(l10n.printBluetooth, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _BluetoothPrinterList(data: data),
          ],
        ),
      ),
    );
  }
}

class _BluetoothPrinterList extends StatelessWidget {
  const _BluetoothPrinterList({required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocConsumer<PrinterCubit, PrinterState>(
      listenWhen: (previous, current) =>
          current.outcome != null && current.outcome != previous.outcome,
      listener: (context, state) {
        if (state.outcome == PrintOutcome.success) {
          showInfoSnack(context, context.l10n.printSuccess);
        } else {
          showErrorSnack(context, context.l10n.printError);
        }
      },
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(state.scanning ? l10n.printScanning : l10n.printScan),
            onPressed: state.scanning
                ? null
                : () => context.read<PrinterCubit>().startScan(),
          ),
          const SizedBox(height: 8),
          if (state.printing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.printers.isEmpty)
            Text(
              l10n.printNoPrinters,
              style: theme.textTheme.bodySmall,
            )
          else
            for (final printer in state.printers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print),
                title: Text(printer.name),
                subtitle: Text(printer.address),
                onTap: () =>
                    context.read<PrinterCubit>().print(printer, data),
              ),
        ],
      ),
    );
  }
}
