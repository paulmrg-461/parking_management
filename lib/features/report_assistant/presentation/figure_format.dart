import 'package:flutter/widgets.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../domain/entities/assistant_answer.dart';

class FigureFormatter {
  const FigureFormatter._();

  static String format(
    AssistantFigure figure,
    String currency,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final value = figure.value;
    if (value == null) {
      return l10n.assistantUndefinedValue;
    }
    return switch (figure.unit) {
      FigureUnit.money => Money.formatAs(currency, value),
      FigureUnit.count => '$value',
      FigureUnit.percent => _percent(value, locale),
      FigureUnit.hour => '${value.toString().padLeft(2, '0')}:00',
    };
  }

  static String _percent(int basisPoints, Locale locale) {
    final text = (basisPoints / 100).toStringAsFixed(2);
    return '${locale.languageCode == 'es' ? text.replaceAll('.', ',') : text} %';
  }

  static String headline(
    AssistantAnswer answer,
    AppLocalizations l10n,
    Locale locale,
  ) {
    var text = answer.headline;
    for (final figure in answer.figures) {
      text = text.replaceAll(
        '{${figure.id}}',
        format(figure, answer.currency, l10n, locale),
      );
    }
    // A placeholder without a figure must never leak raw braces.
    return text.replaceAll(RegExp(r'\{f\d+\}'), '—');
  }

  static String explanation(
    AssistantAnswer answer,
    AppLocalizations l10n,
    Locale locale,
  ) {
    var text = answer.explanation;
    for (final figure in answer.figures) {
      text = text.replaceAll(
        '{${figure.id}}',
        format(figure, answer.currency, l10n, locale),
      );
    }
    return text.replaceAll(RegExp(r'\{f\d+\}'), '—');
  }
}
