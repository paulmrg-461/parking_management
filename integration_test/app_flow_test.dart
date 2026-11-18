// AGENTS section 6 names this file as the Linux integration entry point. The
// real flow lives in `test/integration/supabase_flow_test.dart` (it needs the
// local stack); this wrapper keeps the documented command green until the
// flow is migrated to this harness.
import 'package:flutter_test/flutter_test.dart';

import '../test/integration/supabase_flow_test.dart' as flow;

void main() {
  // Re-export the flow's group so `flutter test -d linux` finds real tests
  // here without duplicating the suite.
  group('supabase flow', flow.main);
}
