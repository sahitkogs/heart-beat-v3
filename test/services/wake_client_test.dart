import 'dart:async';
import 'dart:convert';

import 'package:app_v3/core/hex_codec.dart';
import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/signing_service.dart';
import 'package:app_v3/services/wake_client.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _MemoryStorage implements SecureKeyValueStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._respond);

  final Future<http.StreamedResponse> Function(http.BaseRequest req) _respond;
  http.BaseRequest? lastRequest;
  List<int>? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) {
      lastBody = request.bodyBytes;
    }
    return _respond(request);
  }
}

http.StreamedResponse _streamedJson(int statusCode, String body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late KeyStorage keys;
  late SigningService signing;

  setUp(() async {
    keys = KeyStorage(_MemoryStorage());
    await IdentityService(keys).loadOrCreate();
    signing = SigningService(keys);
  });

  test('wake success — signs `<ts>\\n<body>` and returns ok', () async {
    final fake = _FakeHttpClient(
      (_) async => _streamedJson(200, '{"ok":true}'),
    );
    final client = WakeClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final senderHex = await signing.publicKeyHex();
    final recipientHex = 'a' * 64;
    final envelope = [0x01, 0x02, 0x03];

    final result = await client.wake(
      senderPubkeyHex: senderHex,
      recipientPubkeyHex: recipientHex,
      envelope: envelope,
    );
    expect(result.ok, isTrue);

    final req = fake.lastRequest!;
    expect(req.method, 'POST');
    expect(req.url.path, '/v1/wake');
    expect(req.headers['Content-Type'], 'application/json');
    expect(req.headers['X-Heartbeat-Pubkey'], isNotNull);
    expect(req.headers['X-Heartbeat-Sig'], isNotNull);
    expect(req.headers['X-Heartbeat-Timestamp'], isNotNull);

    final bodyStr = utf8.decode(fake.lastBody!);
    final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;
    expect(bodyJson['recipient_pubkey'], recipientHex);
    // opaque_payload = base64(senderBytes || envelope), so length=35 bytes.
    final raw = base64Decode(bodyJson['opaque_payload'] as String);
    expect(raw.length, 32 + envelope.length);
    expect(raw.sublist(32), envelope);

    // Verify signature against canonical `<ts>\n<body>`.
    final ts = req.headers['X-Heartbeat-Timestamp']!;
    final pubHex = req.headers['X-Heartbeat-Pubkey']!;
    final sigHex = req.headers['X-Heartbeat-Sig']!;
    final canonical = utf8.encode('$ts\n$bodyStr');
    final algo = Ed25519();
    final ok = await algo.verify(
      canonical,
      signature: Signature(
        hexToBytes(sigHex),
        publicKey: SimplePublicKey(
          hexToBytes(pubHex),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    expect(ok, isTrue,
        reason: 'X-Heartbeat-Sig must verify against `<ts>\\n<body>`');
  });

  test('wake unauthorized — 401 surfaces as WakeStatus.unauthorized', () async {
    final fake = _FakeHttpClient(
      (_) async => _streamedJson(401, 'invalid signature'),
    );
    final client = WakeClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );
    final senderHex = await signing.publicKeyHex();

    final result = await client.wake(
      senderPubkeyHex: senderHex,
      recipientPubkeyHex: 'b' * 64,
      envelope: const [1],
    );
    expect(result.ok, isFalse);
    expect(result.status, WakeStatus.unauthorized);
    expect(result.detail, contains('invalid signature'));
  });

  test('wake network error — surfaces as networkError without throwing',
      () async {
    final fake = _FakeHttpClient(
      (_) async => throw const _FakeNetworkException('connect refused'),
    );
    final client = WakeClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );
    final senderHex = await signing.publicKeyHex();

    final result = await client.wake(
      senderPubkeyHex: senderHex,
      recipientPubkeyHex: 'b' * 64,
      envelope: const [1],
    );
    expect(result.status, WakeStatus.networkError);
    expect(result.detail, contains('connect refused'));
  });
}

class _FakeNetworkException implements Exception {
  const _FakeNetworkException(this.message);
  final String message;
  @override
  String toString() => '_FakeNetworkException: $message';
}
