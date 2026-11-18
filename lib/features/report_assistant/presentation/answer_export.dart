import 'package:flutter/widgets.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities/assistant_answer.dart';
import 'figure_format.dart';

String answerAsText(
  AssistantAnswer answer,
  AppLocalizations l10n, {
  String currency = 'COP',
  String locale = 'es',
}) {
  final loc = Locale(locale);
  final buffer = StringBuffer()
    ..writeln(FigureFormatter.headline(answer, l10n, loc))
    ..writeln()
    ..writeln(FigureFormatter.explanation(answer, l10n, loc));
  if (answer.periodStart != null && answer.periodEnd != null) {
    buffer.writeln();
    buffer.writeln(
      l10n.assistantPeriod(
        _date(answer.periodStart!),
        _date(answer.periodEnd!),
      ),
    );
  }
  for (final figure in answer.figures) {
    buffer.writeln(
      '- ${figure.label}: '
      '${FigureFormatter.format(figure, currency, l10n, loc)}',
    );
  }
  for (final caveat in answer.caveats) {
    buffer.writeln('- $caveat');
  }
  buffer
    ..writeln()
    ..writeln(l10n.assistantDisclaimer);
  return buffer.toString().trim();
}

String answerFiguresCsv(AssistantAnswer answer) {
  String cell(Object? value) {
    final text = (value ?? '').toString();
    return text.contains(RegExp('[",\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  final rows = <List<Object?>>[
    ['label', 'unit', 'value', 'rpc', 'path'],
    for (final figure in answer.figures)
      for (final source in figure.sources)
        [figure.label, figure.unit.name, figure.value, source.rpc, source.path],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
