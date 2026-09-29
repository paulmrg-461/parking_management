import 'package:hive_ce/hive_ce.dart';

import '../../core/storage/models/app_settings.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/categories/domain/entities/category.dart';
import '../../features/monthly_passes/domain/entities/monthly_pass.dart';
import '../../features/settings/domain/entities/parking_settings.dart';
import '../../features/tariffs/domain/entities/tariff.dart';
import '../../features/vehicles/domain/entities/vehicle.dart';

@GenerateAdapters([
  AdapterSpec<AppSettings>(),
  AdapterSpec<User>(),
  AdapterSpec<UserRole>(),
  AdapterSpec<AuthSession>(),
  AdapterSpec<Category>(),
  AdapterSpec<Tariff>(),
  AdapterSpec<TariffType>(),
  AdapterSpec<Vehicle>(),
  AdapterSpec<MonthlyPass>(),
  AdapterSpec<ParkingSettings>(),
])
part 'hive_adapters.g.dart';
