import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'branding_cubit.dart';

/// Whether the active site queues customer messages for the WhatsApp
/// dispatcher (true) or opens `wa.me` on the device (false). Missing branding
/// state means "manual", the safe default.
bool whatsappAutoEnabled(BuildContext context) {
  try {
    final settings = context.read<BrandingCubit>().state.settingsOrNull;
    return settings?.whatsappAuto ?? false;
  } on ProviderNotFoundException {
    return false;
  }
}
