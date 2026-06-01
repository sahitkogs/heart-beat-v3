import 'package:flutter_test/flutter_test.dart';
import 'package:app_v3/services/presence_client.dart';
import 'package:app_v3/features/presence/presence_status.dart';

void main() {
  final now = DateTime.utc(2026, 5, 31, 12, 0, 0);

  test('online when server says online', () {
    expect(presenceStatusFor(const PresenceInfo(online: true), now),
        PresenceStatus.online);
  });

  test('recent when seen within 24h', () {
    final info = PresenceInfo(
        online: false, lastSeen: now.subtract(const Duration(hours: 5)));
    expect(presenceStatusFor(info, now), PresenceStatus.recent);
  });

  test('stale when seen over 24h ago', () {
    final info = PresenceInfo(
        online: false, lastSeen: now.subtract(const Duration(days: 3)));
    expect(presenceStatusFor(info, now), PresenceStatus.stale);
  });

  test('stale when never seen', () {
    expect(presenceStatusFor(const PresenceInfo(online: false), now),
        PresenceStatus.stale);
  });

  test('unknown when no presence info at all', () {
    expect(presenceStatusFor(null, now), PresenceStatus.unknown);
  });
}
