import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/categories/application/categories_cubit.dart';
import '../../../features/categories/presentation/categories_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildCategoriesEntry() => BlocProvider<CategoriesCubit>(
  create: (_) => serviceLocator<CategoriesCubit>(),
  child: const CategoriesPage(),
);
