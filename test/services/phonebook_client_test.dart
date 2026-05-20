import 'dart:async';
import 'dart:convert';

import 'package:app_v3/core/hex_codec.dart';
import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/phonebook_client.dart';
import 'package:app_v3/services/signing_service.dart';
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

/// Fake [http.Client] that captures the request and returns a canned
/// response. Set [throwOn] to make `send` throw, simulating a network error.
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

  test('register success — sends signed POST and returns ok', () async {
    final fake = _FakeHttpClient(
      (_) async => _streamedJson(200, '{"ok":true}'),
    );
    final client = PhonebookClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final result = await client.register(
      fcmToken: 'tok-abc',
      platform: 'android',
    );

    expect(result.ok, isTrue);
    expect(result.status, PhonebookRegisterStatus.ok);

    // Validate the request the client actually made.
    final req = fake.lastRequest!;
    expect(req.method, 'POST');
    expect(req.url.path, '/v1/phonebook/register');
    expect(req.headers['Content-Type'], 'application/json');
    expect(req.headers['X-Heartbeat-Pubkey'], isNotNull);
    expect(req.headers['X-Heartbeat-Sig'], isNotNull);
    expect(req.headers['X-Heartbeat-Timestamp'], isNotNull);

    final bodyJson = jsonDecode(utf8.decode(fake.lastBody!));
    expect(bodyJson, {'fcm_token': 'tok-abc', 'platform': 'android'});

    // The signature must verify against the canonical `<ts>\n<body>`.
    final ts = req.headers['X-Heartbeat-Timestamp']!;
    final pubHex = req.headers['X-Heartbeat-Pubkey']!;
    final sigHex = req.headers['X-Heartbeat-Sig']!;
    final canonical = utf8.encode('$ts\n${utf8.decode(fake.lastBody!)}');
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

  test('register unauthorized — surfaces 401 distinctly', () async {
    final fake = _FakeHttpClient(
      (_) async => _streamedJson(401, 'invalid signature'),
    );
    final client = PhonebookClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final result = await client.register(
      fcmToken: 'tok-x',
      platform: 'android',
    );
    expect(result.ok, isFalse);
    expect(result.status, PhonebookRegisterStatus.unauthorized);
    expect(result.detail, contains('invalid signature'));
  });

  test('register network error — surfaces as networkError without throwing',
      () async {
    final fake = _FakeHttpClient(
      (_) async => throw FakeNetworkException('connect refused'),
    );
    final client = PhonebookClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final result = await client.register(
      fcmToken: 'tok-x',
      platform: 'android',
    );
    expect(result.ok, isFalse);
    expect(result.status, PhonebookRegisterStatus.networkError);
    expect(result.detail, contains('connect refused'));
  });
}

/// Tiny exception shim so we don't have to import `dart:io` into the test
/// just to construct a SocketException. PhonebookClient catches every
/// exception type, so any subtype exercises the network-error path.
class FakeNetworkException implements Exception {
  const FakeNetworkException(this.message);
  final String message;
  @override
  String toString() => 'FakeNetworkException: $message';
}
