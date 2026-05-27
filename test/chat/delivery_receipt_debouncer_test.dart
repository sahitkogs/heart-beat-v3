import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/chat/delivery_receipt_debouncer.dart';
import 'package:app_v3/chat/group_envelope.dart';

/// Records the envelopes the debouncer ships, so tests can assert without
/// touching a real CryptoService / RelayClient.
class _RecordingSender implements ReceiptSender {
  final calls = <_Call>[];
  String? displayName;
  @override
  Future<String?> currentDisplayName() async => displayName;
  @override
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes) async {
    calls.add(_Call(peer, envelopeBytes));
  }
}

class _Call {
  _Call(this.peer, this.bytes);
  final String peer;
  final List<int> bytes;
}

void main() {
  late _RecordingSender sender;
  late DeliveryReceiptDebouncer deb;

  setUp(() {
    sender = _RecordingSender();
    deb = DeliveryReceiptDebouncer(sender);
  });

  tearDown(() => deb.dispose());

  test('delivered within 250ms is batched into one envelope', () async {
    deb.enqueueDelivered(peer: 'A', msgId: 'm1');
    deb.enqueueDelivered(peer: 'A', msgId: 'm2');
    deb.enqueueDelivered(peer: 'A', msgId: 'm3');
    expect(sender.calls, isEmpty); // not yet flushed

    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(sender.calls, hasLength(1));
    final parsed = InnerEnvelope.parse(sender.calls.single.bytes)
        as DeliveryReceiptEnvelope;
    expect(parsed.msgIds, ['m1', 'm2', 'm3']);
    expect(parsed.kind, ReceiptKind.delivered);
  });

  test('multi-peer batches stay independent', () async {
    deb.enqueueDelivered(peer: 'A', msgId: 'a1');
    deb.enqueueDelivered(peer: 'B', msgId: 'b1');
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(sender.calls, hasLength(2));
    final peers = sender.calls.map((c) => c.peer).toSet();
    expect(peers, {'A', 'B'});
  });

  test('enqueueRead flushes immediately and bypasses the 250ms timer', () async {
    deb.enqueueRead(peer: 'A', msgIds: ['m1', 'm2']);
    await pumpEventQueue();
    expect(sender.calls, hasLength(1));
    final parsed = InnerEnvelope.parse(sender.calls.single.bytes)
        as DeliveryReceiptEnvelope;
    expect(parsed.kind, ReceiptKind.read);
    expect(parsed.msgIds, ['m1', 'm2']);
  });

  test('enqueueRead with empty list is a no-op', () async {
    deb.enqueueRead(peer: 'A', msgIds: []);
    await pumpEventQueue();
    expect(sender.calls, isEmpty);
  });
}
