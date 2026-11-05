import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/locale_cubit.dart';
import 'package:parking_management/core/security/auto_lock_cubit.dart';
import 'package:parking_management/core/theme/theme_cubit.dart';
import 'package:parking_management/features/preferences/presentation/preferences_page.dart';

import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/test_app.dart';

Future<(LocaleCubit, ThemeCubit, AutoLockCubit)> _pump(
  WidgetTester tester,
) async {
  final locale = LocaleCubit(FakeKeyValueStore());
  final theme = ThemeCubit(FakeKeyValueStore());
  final lock = AutoLockCubit(FakeKeyValueStore());
  addTearDown(locale.close);
  addTearDown(theme.close);
  addTearDown(lock.close);
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<LocaleCubit>.value(value: locale),
          BlocProvider<ThemeCubit>.value(value: theme),
          BlocProvider<AutoLockCubit>.value(value: lock),
        ],
        child: const PreferencesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (locale, theme, lock);
}

void main() {
  testWidgets('Success: shows the device preferences and shortcuts', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.widgetWithText(AppBar, 'Ajustes'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Bloqueo automático'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
    expect(find.text('Acerca de'), findsOneWidget);
  });

  testWidgets('Success: language, theme and idle lock are selectable', (
    tester,
  ) async {
    final (locale, theme, lock) = await _pump(tester);

    await tester.tap(find.text('Idioma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(locale.state?.languageCode, 'en');

    // This harness pins the MaterialApp locale to Spanish, so the labels stay
    // in Spanish even after the cubit change; the state is what matters here.
    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(theme.state, ThemeMode.light);

    await tester.tap(find.text('Bloqueo automático'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 min'));
    await tester.pumpAndSettle();
    expect(lock.minutes, 1);
  });
}
