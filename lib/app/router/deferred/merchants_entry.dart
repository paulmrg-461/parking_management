import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/merchants/application/merchant_settlement_cubit.dart';
import '../../../features/merchants/application/merchants_cubit.dart';
import '../../../features/merchants/presentation/merchants_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin agreements screen (list + settlement).
Widget buildMerchantsEntry() => MultiBlocProvider(
  providers: [
    BlocProvider<MerchantsCubit>(create: (_) => serviceLocator<MerchantsCubit>()),
    BlocProvider<MerchantSettlementCubit>(
      create: (_) => serviceLocator<MerchantSettlementCubit>(),
    ),
  ],
  child: const MerchantsPage(),
);
