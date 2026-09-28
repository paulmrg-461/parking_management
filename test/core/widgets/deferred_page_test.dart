import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/deferred_page.dart';

void main() {
  testWidgets('Success: shows a spinner, then the page once loaded', (
    tester,
  ) async {
    final loading = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredPage(
          loader: () => loading.future,
          builder: (_) => const Text('Loaded page'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    loading.complete();
    await tester.pumpAndSettle();

    expect(find.text('Loaded page'), findsOneWidget);
  });

  testWidgets('Failure: a failed load offers a retry that loads again', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredPage(
          loader: () async {
            attempts++;
            if (attempts == 1) {
              throw Exception('chunk download failed');
            }
          },
          builder: (_) => const Text('Loaded page'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this section'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Loaded page'), findsOneWidget);
  });

  testWidgets(
    'Security: the deferred builder never runs before the load completes',
    (tester) async {
      var built = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DeferredPage(
            loader: () => Completer<void>().future,
            builder: (_) {
              built = true;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));

      expect(built, isFalse);
    },
  );
}
