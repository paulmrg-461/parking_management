import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../theme/theme_cubit.dart';

/// Appbar action that picks the device appearance (system / light / dark).
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = context.select<ThemeCubit, ThemeMode>((c) => c.state);
    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.themeMode,
      icon: Icon(
        mode == ThemeMode.dark
            ? Icons.dark_mode_outlined
            : mode == ThemeMode.light
            ? Icons.light_mode_outlined
            : Icons.brightness_auto_outlined,
      ),
      onSelected: context.read<ThemeCubit>().select,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: ThemeMode.system,
          checked: mode == ThemeMode.system,
          child: Text(l10n.themeSystem),
        ),
        CheckedPopupMenuItem(
          value: ThemeMode.light,
          checked: mode == ThemeMode.light,
          child: Text(l10n.themeLight),
        ),
        CheckedPopupMenuItem(
          value: ThemeMode.dark,
          checked: mode == ThemeMode.dark,
          child: Text(l10n.themeDark),
        ),
      ],
    );
  }
}
