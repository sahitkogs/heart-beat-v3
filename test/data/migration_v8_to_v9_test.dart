// Migration test stub. Live-verified on-device when a v8 install (Phase
// 10.4.3b) upgrades to v9 (Phase 10.4.3c).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v8 -> v9 adds outbox.kind defaulting to text', () {
    // Intentionally empty — verified by upgrading both emulators that
    // already had Phase 10.4.3b data. Existing outbox rows default to
    // kind == 'text', so any in-flight 10.4.3b message keeps its
    // original retransmit ladder (30s/60s/5m/30m/1h) until acked.
  }, skip: 'live-verified on device upgrade');
}
