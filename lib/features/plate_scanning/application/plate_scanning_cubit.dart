import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/normalize_plate.dart';
import '../domain/repositories/plate_scanner.dart';

sealed class PlateScanningState extends Equatable {
  const PlateScanningState();

  @override
  List<Object?> get props => const [];
}

class PlateScanningInitial extends PlateScanningState {
  const PlateScanningInitial();
}

class PlateScanningCapturing extends PlateScanningState {
  const PlateScanningCapturing();
}

class PlateScanningScanning extends PlateScanningState {
  const PlateScanningScanning();
}

class PlateScanningSuccess extends PlateScanningState {
  const PlateScanningSuccess(this.candidatePlate, this.confidence);

  final String candidatePlate;
  final double confidence;

  @override
  List<Object?> get props => [candidatePlate, confidence];
}

class PlateScanningFailure extends PlateScanningState {
  const PlateScanningFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class PlateScanningManualEntry extends PlateScanningState {
  const PlateScanningManualEntry({this.prefill = ''});

  final String prefill;

  @override
  List<Object?> get props => [prefill];
}

/// Orchestrates the plate-scanning flow: capture -> OCR scan -> normalize ->
/// emit a reviewable candidate, or fall back to manual entry when the OCR
/// adapter can't produce a usable candidate.
class PlateScanningCubit extends Cubit<PlateScanningState> {
  PlateScanningCubit(this._scanner) : super(const PlateScanningInitial());

  final PlateScanner _scanner;

  /// Signals that image capture has started (called before invoking the
  /// device camera), so the UI can show progress.
  void startCapture() => emit(const PlateScanningCapturing());

  /// Scans [image] for a plate and emits the resulting candidate, or falls
  /// back to manual entry when OCR finds no plate-like text.
  Future<void> scan(File image) async {
    emit(const PlateScanningScanning());
    try {
      final result = await _scanner.scan(image);
      if (result.candidatePlate.isEmpty) {
        emit(PlateScanningManualEntry(prefill: result.rawText));
        return;
      }
      emit(PlateScanningSuccess(normalizePlate(result.candidatePlate), result.confidence));
    } on Failure catch (failure) {
      emit(PlateScanningFailure(failure.message));
    }
  }

  /// Switches to manual entry, optionally pre-filled with [prefill] text
  /// (e.g. the raw OCR output that failed automatic normalization).
  void enterManually({String prefill = ''}) =>
      emit(PlateScanningManualEntry(prefill: prefill));

  /// Confirms a manually entered plate, normalizing and validating it.
  void confirmManual(String rawInput) {
    try {
      emit(PlateScanningSuccess(normalizePlate(rawInput), 1.0));
    } on Failure catch (failure) {
      emit(PlateScanningFailure(failure.message));
    }
  }
}
