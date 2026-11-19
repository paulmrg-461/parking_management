import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_cubit.dart';
import '../../../core/security/auto_lock_cubit.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/version/app_version.dart';
import '../../../core/widgets/auto_lock_menu.dart';
import '../../../app/router/route_access.dart';

/// Device preferences: language, appearance and idle lock, plus shortcuts to
/// Help and About. Reached from the drawer and the desktop sidebar so the app
/// bars stay free of preference icons.
class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = _locale(context);
    final themeCubit = _theme(context);
    final autoLock = _autoLock(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.preferencesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.preferencesHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (locale != null)
                          ListTile(
                            leading: const Icon(Icons.translate),
                            title: Text(l10n.languageTooltip),
                            subtitle: Text(_languageName(l10n, locale.state)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _pickLanguage(context, locale),
                          ),
                        if (themeCubit != null)
                          ListTile(
                            leading: Icon(_themeIcon(themeCubit.state)),
                            title: Text(l10n.themeMode),
                            subtitle: Text(_themeName(l10n, themeCubit.state)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _pickTheme(context, themeCubit),
                          ),
                        if (autoLock != null)
                          ListTile(
                            leading: const Icon(Icons.lock_clock),
                            title: Text(l10n.autoLockTitle),
                            subtitle: Text(
                              autoLockLabel(l10n, autoLock.minutes),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showAutoLockSheet(context, autoLock),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: Text(l10n.helpTitle),
                          subtitle: Text(l10n.helpIntro),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(helpPath),
                        ),
                        ListTile(
                          leading: const Icon(Icons.code),
                          title: Text(l10n.aboutTitle),
                          subtitle: Text(l10n.aboutMadeBy),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(aboutPath),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    l10n.aboutRights,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    l10n.aboutVersion('$appVersion ($appBuildNumber)'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LocaleCubit? _locale(BuildContext context) {
    try {
      return context.watch<LocaleCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  ThemeCubit? _theme(BuildContext context) {
    try {
      return context.watch<ThemeCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  AutoLockCubit? _autoLock(BuildContext context) {
    try {
      return context.watch<AutoLockCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  String _languageName(AppLocalizations l10n, Locale? locale) =>
      switch (locale?.languageCode) {
        'es' => l10n.languageSpanish,
        'en' => l10n.languageEnglish,
        _ => l10n.languageSystem,
      };

  String _themeName(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l10n.themeLight,
    ThemeMode.dark => l10n.themeDark,
    ThemeMode.system => l10n.themeSystem,
  };

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  Future<void> _pickLanguage(BuildContext context, LocaleCubit cubit) async {
    final l10n = context.l10n;
    final current = cubit.state?.languageCode ?? 'system';
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              ('system', l10n.languageSystem),
              ('es', l10n.languageSpanish),
              ('en', l10n.languageEnglish),
            ])
              ListTile(
                leading: Icon(
                  option.$1 == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(option.$2),
                selected: option.$1 == current,
                onTap: () => Navigator.of(sheet).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    await cubit.select(choice == 'system' ? null : Locale(choice));
  }

  Future<void> _pickTheme(BuildContext context, ThemeCubit cubit) async {
    final l10n = context.l10n;
    final current = cubit.state;
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              (ThemeMode.system, l10n.themeSystem),
              (ThemeMode.light, l10n.themeLight),
              (ThemeMode.dark, l10n.themeDark),
            ])
              ListTile(
                leading: Icon(
                  option.$1 == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(option.$2),
                selected: option.$1 == current,
                onTap: () => Navigator.of(sheet).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    await cubit.select(choice);
  }
}
