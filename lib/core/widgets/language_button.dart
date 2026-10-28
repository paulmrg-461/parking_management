import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../l10n/locale_cubit.dart';

/// Language picker (system / Spanish / English), device-local.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<LocaleCubit>();
    final current = context.select<LocaleCubit, String?>(
      (c) => c.state?.languageCode,
    );
    return PopupMenuButton<String>(
      tooltip: l10n.languageTooltip,
      icon: const Icon(Icons.translate),
      onSelected: (value) =>
          cubit.select(value == 'system' ? null : Locale(value)),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'system',
          checked: current == null,
          child: Text(l10n.languageSystem),
        ),
        CheckedPopupMenuItem(
          value: 'es',
          checked: current == 'es',
          child: Text(l10n.languageSpanish),
        ),
        CheckedPopupMenuItem(
          value: 'en',
          checked: current == 'en',
          child: Text(l10n.languageEnglish),
        ),
      ],
    );
  }
}
