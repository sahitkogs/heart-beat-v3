import 'dart:async';
import 'dart:convert';

import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/presence_client.dart';
import 'package:app_v3/services/signing_service.dart';
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

/// Fake [http.Client] that captures the request and returns a canned response.
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

  test('fetchPresence — sends signed POST and parses presence map', () async {
    const responseBody =
        '{"presence":{"aa11":{"online":true,"last_seen":1717160000},'
        '"bb22":{"online":false,"last_seen":0}}}';

    final fake = _FakeHttpClient(
      (_) async => _streamedJson(200, responseBody),
    );
    final client = PresenceClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final res = await client.fetchPresence(['aa11', 'bb22']);

    // Path and signing headers.
    final req = fake.lastRequest!;
    expect(req.method, 'POST');
    expect(req.url.path, '/v1/presence');
    expect(req.headers['X-Heartbeat-Pubkey'], isNotNull);
    expect(req.headers['X-Heartbeat-Sig'], isNotNull);
    expect(req.headers['X-Heartbeat-Timestamp'], isNotNull);

    // Parsed results.
    expect(res['aa11']!.online, isTrue);
    expect(res['aa11']!.lastSeen, isNotNull);
    expect(
      res['aa11']!.lastSeen,
      DateTime.fromMillisecondsSinceEpoch(1717160000 * 1000, isUtc: true),
    );

    expect(res['bb22']!.online, isFalse);
    expect(res['bb22']!.lastSeen, isNull); // last_seen == 0 → null
  });

  test('fetchPresence — returns empty map on 500 (best-effort, no throw)',
      () async {
    final fake = _FakeHttpClient(
      (_) async => _streamedJson(500, 'internal server error'),
    );
    final client = PresenceClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final res = await client.fetchPresence(['aa11', 'bb22']);
    expect(res, isEmpty);
  });

  test('fetchPresence — returns empty map on network error (no throw)',
      () async {
    final fake = _FakeHttpClient(
      (_) async => throw Exception('connect refused'),
    );
    final client = PresenceClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: fake,
    );

    final res = await client.fetchPresence(['aa11', 'bb22']);
    expect(res, isEmpty);
  });
}
