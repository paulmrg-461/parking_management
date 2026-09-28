import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Spanish (Colombia) is the product default; English is secondary.
const defaultLocale = Locale('es');

/// Locale tag used for dates and money (`es_CO`: `$ 1.500`, `25/09/2026`).
const formatLocale = 'es_CO';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
