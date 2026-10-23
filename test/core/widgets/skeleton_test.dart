import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/core/theme/app_theme.dart';
import 'package:parking_management/core/widgets/skeleton.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  locale: defaultLocale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('Success: renders one placeholder row per item', (tester) async {
    await tester.pumpWidget(_wrap(const SkeletonList(itemCount: 3)));

    // Avatar plus two text lines per row.
    expect(find.byType(SkeletonBox), findsNWidgets(9));
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });

  testWidgets('A11y: reduce motion renders a static skeleton', (tester) async {
    await tester.pumpWidget(
      _wrap(const SkeletonList(itemCount: 2), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(SkeletonList),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 0.45);
  });
}
