import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/failure.dart';
import '../application/plate_scanning_cubit.dart';
import '../domain/normalize_plate.dart';
import '../infrastructure/image_picker_plate_capture.dart';

/// Captures a vehicle plate via camera OCR, with an always-reachable manual
/// entry fallback. Pops the confirmed, normalized candidate plate.
class PlateScanPage extends StatefulWidget {
  const PlateScanPage({super.key, this.capture});

  /// Overridable image-capture mechanism, injected in tests to avoid
  /// invoking the real device camera.
  final PlateImageCapture? capture;

  @override
  State<PlateScanPage> createState() => _PlateScanPageState();
}

class _PlateScanPageState extends State<PlateScanPage> {
  final _plateController = TextEditingController();
  late final PlateImageCapture _capture = widget.capture ?? ImagePickerPlateCapture();

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan(BuildContext context) async {
    final cubit = context.read<PlateScanningCubit>();
    cubit.startCapture();
    final XFile? image = await _capture.capture();
    if (image == null) {
      cubit.enterManually();
      return;
    }
    await cubit.scan(File(image.path));
  }

  void _confirm(BuildContext context) {
    try {
      Navigator.of(context).pop(normalizePlate(_plateController.text));
    } on ValidationFailure {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a plate before confirming')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan plate')),
      body: BlocConsumer<PlateScanningCubit, PlateScanningState>(
        listener: _syncControllerWithState,
        builder: (context, state) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => _captureAndScan(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture plate'),
              ),
              if (state is PlateScanningScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state is PlateScanningFailure)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    state.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (state is PlateScanningManualEntry)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Enter the plate manually'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plate'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<PlateScanningCubit>().enterManually(),
                child: const Text('Enter manually'),
              ),
              FilledButton(
                onPressed: () => _confirm(context),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncControllerWithState(BuildContext context, PlateScanningState state) {
    if (state is PlateScanningSuccess) {
      _plateController.text = state.candidatePlate;
    } else if (state is PlateScanningManualEntry) {
      _plateController.text = state.prefill;
    }
  }
}
