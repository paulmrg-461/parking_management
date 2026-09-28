import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Loads intl date symbols (es_CO formatting) once for every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
