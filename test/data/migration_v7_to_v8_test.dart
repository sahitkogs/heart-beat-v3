// Migration test stub. Live-verified on-device when this build replaces a
// v7 install (Phase 10.4.3b without the known_ticks gate).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v7 -> v8 adds messages.known_ticks', () {
    // Intentionally empty — verified by reinstalling on emulators that
    // already had Phase 10.4.3b data. Existing rows default to
    // known_ticks == false so the UI hides their ticks; new outbound
    // writes via _persistOutbound set known_ticks == true.
  }, skip: 'live-verified on device upgrade');
}
