import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/spots/application/spots_cubit.dart';
import '../../../features/spots/presentation/spots_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildSpotsEntry({required bool isAdmin}) => BlocProvider<SpotsCubit>(
  create: (_) => serviceLocator<SpotsCubit>(),
  child: SpotsPage(isAdmin: isAdmin),
);
