import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/presentation/settings_page.dart';
import '../../../features/spots/domain/repositories/spot_repository.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildSettingsEntry() => BlocProvider<SettingsCubit>(
  create: (_) => serviceLocator<SettingsCubit>(),
  child: SettingsPage(
    spots: serviceLocator.isRegistered<SpotRepository>()
        ? serviceLocator<SpotRepository>()
        : null,
  ),
);
