import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/staggered_list_item.dart';

void main() {
  testWidgets('Success: a row fades in and settles fully visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StaggeredListItem(child: Text('fila')),
        ),
      ),
    );

    final start = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(start, lessThan(1));

    await tester.pumpAndSettle();

    expect(find.text('fila'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('Failure: reduce motion shows the row immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StaggeredListItem(child: Text('fila')),
          ),
        ),
      ),
    );

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('fila'), findsOneWidget);
  });

  testWidgets('Security: a keyed row keeps its child across rebuilds', (
    tester,
  ) async {
    Widget build(String label) => MaterialApp(
      home: Scaffold(
        body: StaggeredListItem(key: const ValueKey(1), child: Text(label)),
      ),
    );

    await tester.pumpWidget(build('primera'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build('segunda'));
    await tester.pumpAndSettle();

    expect(find.text('segunda'), findsOneWidget);
    expect(find.text('primera'), findsNothing);
  });
}
