import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// A local date-time formatted for es_CO (`5/9/2026 14:07`).
class DateTimeText extends StatelessWidget {
  const DateTimeText(this.value, {super.key, this.style, this.dateOnly = false});

  final DateTime value;
  final TextStyle? style;
  final bool dateOnly;

  @override
  Widget build(BuildContext context) => Text(
    dateOnly ? Formatters.date(value) : Formatters.dateTime(value),
    style: style,
  );
}
