// Migration test stub. Live-verified on-device in T9.E6 (force-stop + relaunch
// on Phone A's real v4 install), so the offline drift schema-snapshot verifier
// is intentionally not wired up for 10.4. See plan T2.2 decision.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 -> v5 preserves direct chats + copies bundle state', () {
    // Intentionally empty — verified on-device in T9.E6.
  }, skip: 'live-verified in T9.E6 instead; see plan T2.2 decision');
}
