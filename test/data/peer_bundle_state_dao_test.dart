import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/peer_bundle_state_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PeerBundleStateDao dao;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = PeerBundleStateDao(db);
  });
  tearDown(() async => db.close());

  test('returns null for unknown peer', () async {
    final s = await dao.get('peerA');
    expect(s, isNull);
  });

  test('markBundleSent + markPeerBundleReceived persist', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.markBundleSent('peerA', at: t);
    await dao.markPeerBundleReceived('peerA', at: t);
    final s = await dao.get('peerA');
    expect(s, isNotNull);
    expect(s!.bundleSentAt, t);
    expect(s.peerBundleReceivedAt, t);
  });

  test('clearBundleSent only clears the sent flag', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.markBundleSent('peerA', at: t);
    await dao.markPeerBundleReceived('peerA', at: t);
    await dao.clearBundleSent('peerA');
    final s = await dao.get('peerA');
    expect(s!.bundleSentAt, isNull);
    expect(s.peerBundleReceivedAt, t);
  });
}
