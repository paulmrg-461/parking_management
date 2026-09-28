import 'package:flutter/material.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/core/theme/app_theme.dart';

/// A [MaterialApp] with the real theme and localizations (Spanish by
/// default) around [home], for isolated widget tests.
Widget testApp(Widget home, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: AppTheme.build(brightness),
      locale: defaultLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Same localizations/theme for `MaterialApp.router` based tests.
Widget testRouterApp(RouterConfig<Object> router) => MaterialApp.router(
  theme: AppTheme.light(),
  locale: defaultLocale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);
