import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

/// Stub `SenderKeyStore`. Group messaging (sender keys) is not exercised in
/// Heartbeat 1:1 chat — calls throw `UnimplementedError` so we'd notice if
/// anything in libsignal's 1:1 path ever started reaching for it. Real
/// drift-backed impl lands with group chat in Phase 10.4.
class DriftSenderKeyStore extends lsl.SenderKeyStore {
  DriftSenderKeyStore();

  @override
  Future<void> storeSenderKey(
      lsl.SenderKeyName senderKeyName, lsl.SenderKeyRecord record) {
    throw UnimplementedError(
        'DriftSenderKeyStore.storeSenderKey: group messaging lands in 10.4');
  }

  @override
  Future<lsl.SenderKeyRecord> loadSenderKey(lsl.SenderKeyName senderKeyName) {
    throw UnimplementedError(
        'DriftSenderKeyStore.loadSenderKey: group messaging lands in 10.4');
  }
}
