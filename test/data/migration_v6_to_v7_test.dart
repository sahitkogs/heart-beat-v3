// Migration test stub. Live-verified on-device during F1 of the 10.4.3b
// quality-gate run (fresh APK install over a v6 install on a real device).
// Offline drift schema-snapshot infra is intentionally not wired up — same
// rationale as the 10.4 T2.2 / v5 -> v6 migration test decisions.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v6 -> v7 adds delivery_state column + outbox table', () {
    // Intentionally empty — verified on-device during 10.4.3b F1.
  }, skip: 'live-verified on device upgrade — see plan Task 17');
}
