import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/tariffs/application/tariffs_cubit.dart';
import '../../../features/tariffs/presentation/tariffs_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildTariffsEntry() => BlocProvider<TariffsCubit>(
  create: (_) => serviceLocator<TariffsCubit>(),
  child: const TariffsPage(),
);
