import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/invoicing/application/invoicing_cubit.dart';
import '../../../features/invoicing/presentation/invoicing_page.dart';
import '../../di/injection.dart';

/// Deferred entry point for the admin electronic-invoicing screen.
Widget buildInvoicingEntry() => BlocProvider<InvoicingCubit>(
  create: (_) => serviceLocator<InvoicingCubit>(),
  child: const InvoicingPage(),
);
