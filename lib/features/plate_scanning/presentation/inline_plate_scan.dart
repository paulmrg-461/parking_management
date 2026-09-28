import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../application/plate_scanning_cubit.dart';
import '../domain/repositories/plate_image_capture.dart';

/// Takes one photo and OCRs it in place (no page change). Returns the photo
/// so callers can reuse it as evidence, or `null` if the user cancelled.
/// The outcome arrives through [PlateScanListener].
Future<XFile?> captureAndScan(
  PlateScanningCubit cubit,
  PlateImageCapture capture,
) async {
  cubit.startCapture();
  final image = await capture.capture();
  if (image != null) {
    await cubit.scan(image);
  }
  return image;
}

/// Reacts to [PlateScanningCubit] results: a detected plate (with haptic
/// feedback) or an unreadable photo (localized reason + raw OCR prefill).
class PlateScanListener extends StatelessWidget {
  const PlateScanListener({
    super.key,
    required this.onDetected,
    required this.onUnreadable,
    required this.child,
  });

  final ValueChanged<String> onDetected;
  final void Function(String message, String prefill) onUnreadable;
  final Widget child;

  void _listener(BuildContext context, PlateScanningState state) {
    switch (state) {
      case PlateScanningSuccess(:final candidatePlate):
        HapticFeedback.mediumImpact();
        onDetected(candidatePlate);
      case PlateScanningFailure(:final message, :final failure):
        onUnreadable(context.l10n.errorText(message, failure), '');
      case PlateScanningManualEntry(:final prefill):
        onUnreadable(context.l10n.errorOcrNoText, prefill);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<PlateScanningCubit, PlateScanningState>(
        listener: _listener,
        child: child,
      );
}
