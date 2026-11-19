import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/splash/presentation/splash_page.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('Success: the splash shows the brand and a loading indicator', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const SplashPage()));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cargando'), findsOneWidget);
  });
}
