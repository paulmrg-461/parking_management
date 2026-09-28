import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/formatters.dart';
import 'plate_text.dart';

/// One parking session row: plate, localized entry time, optional detail
/// (photos, category) and a trailing action or status.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.plate,
    required this.entryTime,
    this.detail,
    this.trailing,
    this.onTap,
  });

  final String plate;
  final DateTime entryTime;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final entry = context.l10n.sessionEntry(Formatters.dateTime(entryTime));
    return ListTile(
      title: PlateText(plate),
      subtitle: Text(detail == null ? entry : '$entry · $detail'),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
