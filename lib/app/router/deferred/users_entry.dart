import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/users/application/users_cubit.dart';
import '../../../features/users/presentation/users_page.dart';
import '../../di/injection.dart';

/// Deferred entry point (loaded on demand; admin-only).
Widget buildUsersEntry() => BlocProvider<UsersCubit>(
  create: (_) => serviceLocator<UsersCubit>(),
  child: const UsersPage(),
);
