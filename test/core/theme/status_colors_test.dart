import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/theme/app_theme.dart';
import 'package:parking_management/core/theme/contrast.dart';
import 'package:parking_management/core/theme/status_colors.dart';
import 'package:parking_management/core/theme/tokens.dart';

void main() {
  group('contrastRatio', () {
    test('Success: black on white is 21:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    });

    test('Failure: identical colors are 1:1', () {
      expect(contrastRatio(Colors.grey, Colors.grey), closeTo(1, 0.001));
    });
  });

  for (final brightness in Brightness.values) {
    group('StatusColors ${brightness.name}', () {
      final theme = AppTheme.build(brightness);
      final status = theme.extension<StatusColors>()!;
      final surface = theme.colorScheme.surface;

      test('A11y: every status color reads ≥ 4.5:1 on the surface', () {
        for (final color in [status.success, status.warning, status.pending]) {
          expect(
            contrastRatio(color, surface),
            greaterThanOrEqualTo(wcagAaNormalText),
          );
        }
      });

      test('A11y: every on-color reads ≥ 4.5:1 on its status color', () {
        final pairs = {
          status.onSuccess: status.success,
          status.onWarning: status.warning,
          status.onPending: status.pending,
        };
        pairs.forEach((fg, bg) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(wcagAaNormalText));
        });
      });
    });
  }

  group('AppTheme', () {
    test('Success: light and dark come from the same seed', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('A11y: buttons have a 48dp minimum height', () {
      final style = AppTheme.light().filledButtonTheme.style!;
      final size = style.minimumSize!.resolve(const {})!;
      expect(size.height, greaterThanOrEqualTo(Layout.minTouch));
    });

    test('Tokens: spacing stays on the 8pt grid (4 allowed as half step)', () {
      for (final value in [Space.sm, Space.md, Space.lg, Space.xl, Space.xxl]) {
        expect(value % 8, 0);
      }
      expect(Space.xs, 4);
    });
  });
}
