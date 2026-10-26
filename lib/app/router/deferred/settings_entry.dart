import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/presentation/settings_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildSettingsEntry() => BlocProvider<SettingsCubit>(
  create: (_) => serviceLocator<SettingsCubit>(),
  child: const SettingsPage(),
);
