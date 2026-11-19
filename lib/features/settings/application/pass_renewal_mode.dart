import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'branding_cubit.dart';

/// Whether the site sends token-keyed renewal links (reminders + payment).
/// Missing settings or no `BrandingCubit` (isolated page tests) mean "off".
bool passRenewalLinksEnabled(BuildContext context) {
  try {
    final settings = context.watch<BrandingCubit>().state.settingsOrNull;
    return (settings?.passRenewalEnabled ?? false) &&
        (settings?.passRenewalPaymentLinks ?? false) &&
        (settings?.onlinePaymentsEnabled ?? false) &&
        (settings?.currency ?? 'COP') == 'COP';
  } on ProviderNotFoundException {
    return false;
  }
}
