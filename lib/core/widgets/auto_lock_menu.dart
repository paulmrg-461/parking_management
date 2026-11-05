import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../security/auto_lock_cubit.dart';
import '../theme/tokens.dart';

/// Label for the idle-lock preference (`0` = off).
String autoLockLabel(AppLocalizations l10n, int minutes) =>
    minutes == 0 ? l10n.autoLockOff : l10n.autoLockMinutes(minutes);

/// Bottom sheet used by the drawer and the desktop sidebar to pick the idle
/// lock timeout. Stored per device in [AutoLockCubit].
Future<void> showAutoLockSheet(
  BuildContext context,
  AutoLockCubit cubit,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    final l10n = sheet.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
            child: Text(
              l10n.autoLockTitle,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
            child: Text(
              l10n.autoLockHint,
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
          ),
          for (final minutes in AutoLockCubit.options)
            RadioListTile<int>(
              value: minutes,
              groupValue: cubit.minutes,
              title: Text(autoLockLabel(l10n, minutes)),
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                await cubit.select(value);
                if (sheet.mounted) {
                  Navigator.of(sheet).pop();
                }
              },
            ),
          const SizedBox(height: Space.sm),
        ],
      ),
    );
  },
);
