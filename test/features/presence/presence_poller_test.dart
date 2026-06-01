import 'package:flutter_test/flutter_test.dart';
import 'package:app_v3/services/presence_client.dart';
import 'package:app_v3/features/presence/presence_provider.dart';

void main() {
  test('detects offline/stale->online transitions', () {
    final prev = <String, PresenceInfo>{
      'aa': PresenceInfo(online: false),
      'bb': PresenceInfo(online: true),
    };
    final next = <String, PresenceInfo>{
      'aa': PresenceInfo(online: true), // transitioned UP
      'bb': PresenceInfo(online: true), // stayed online
      'cc': PresenceInfo(online: true), // newly seen online
    };
    final ups = newlyOnline(prev, next);
    expect(ups, containsAll(<String>['aa', 'cc']));
    expect(ups.contains('bb'), isFalse);
  });

  test('no transitions when nothing came online', () {
    final prev = <String, PresenceInfo>{'aa': PresenceInfo(online: true)};
    final next = <String, PresenceInfo>{'aa': PresenceInfo(online: true)};
    expect(newlyOnline(prev, next), isEmpty);
  });
}
