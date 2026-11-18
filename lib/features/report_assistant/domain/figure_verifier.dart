import 'entities/assistant_answer.dart';

/// Recomputes a figure from its raw sources. The server already validated the
/// path/unit; this is the client's independent tamper check.
class FigureVerifier {
  const FigureVerifier._();

  static bool verify(AssistantFigure figure) {
    if (figure.value == null) {
      return figure.note == 'undefined_base';
    }
    if (figure.sources.isEmpty) {
      return false;
    }
    final raws = figure.sources.map((source) => source.raw).toList();
    switch (figure.op) {
      case 'value':
        return raws.length == 1 && raws.first == figure.value;
      case 'sum':
        final sum = raws.fold<int>(0, (total, value) => total + value);
        return sum == figure.value;
      case 'difference':
        return raws.length == 2 && raws[0] - raws[1] == figure.value;
      case 'percent_change':
      case 'share_percent':
        if (raws.length != 2) {
          return false;
        }
        final base = figure.op == 'percent_change' ? raws[0] : raws[1];
        if (base == 0) {
          return false;
        }
        final numerator = figure.op == 'percent_change'
            ? (raws[1] - raws[0]) * 10000
            : raws[0] * 10000;
        final rounded = _divRound(numerator, base);
        return rounded == figure.value;
      default:
        return false;
    }
  }

  static int _divRound(int numerator, int denominator) {
    final negative = (numerator < 0) != (denominator < 0);
    final n = numerator.abs();
    final d = denominator.abs();
    final quotient = n ~/ d;
    final remainder = n % d;
    final rounded = remainder * 2 >= d ? quotient + 1 : quotient;
    return negative ? -rounded : rounded;
  }
}
