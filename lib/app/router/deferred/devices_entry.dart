import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/devices/application/devices_cubit.dart';
import '../../../features/devices/presentation/devices_page.dart';
import '../../di/injection.dart';

Widget buildDevicesEntry() => BlocProvider<DevicesCubit>(
  create: (_) => serviceLocator<DevicesCubit>(),
  child: const DevicesPage(),
);
