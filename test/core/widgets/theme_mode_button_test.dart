import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/theme/theme_cubit.dart';
import 'package:parking_management/core/widgets/theme_mode_button.dart';

import '../../helpers/fake_key_value_store.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('Success: picking Oscuro changes and stores the mode', (
    tester,
  ) async {
    final store = FakeKeyValueStore();
    final cubit = ThemeCubit(store);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider<ThemeCubit>.value(
          value: cubit,
          child: const Scaffold(
            appBar: null,
            body: ThemeModeButton(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Apariencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(cubit.state, ThemeMode.dark);
    expect(store.values['preferences/theme_mode'], 'dark');
  });
}
