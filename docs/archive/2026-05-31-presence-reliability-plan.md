# Presence (Green Tick) + Reliability + 3-Emulator Campaign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a server-backed contact-liveness "green tick" to the Heart.Beat v3 client, use a stale→online transition to auto-flush stranded outbox messages (the reliability core), add a records-integrity self-check, then run a 3-emulator edge-case reliability campaign and log findings.

**Architecture:** The Go relay already tracks live WS connections (`Hub.conns`); we add a persisted `last_seen` and a signed `POST /v1/presence` batch query. The Flutter client polls presence for its contacts while foregrounded, paints a 3-state badge, and on a stale/offline→online transition kicks all pending outbox rows for that peer into an immediate retransmit. A read-only integrity check surfaces stuck/orphaned/dangling records.

**Tech Stack:** Go 1.x relay (`modernc.org/sqlite`, `net/http`, `crypto/ed25519`, `nhooyr.io/websocket`); Flutter client (Riverpod, drift, `http`, libsignal); Android emulators driven via `adb`.

**Spec:** `docs/2026-05-31-presence-reliability-design.md`

**Conventions (match existing project):**
- One git commit per task; message format `<area>: <terse> (<task-id>)` with a body explaining why + what was verified.
- Flutter: `$env:PATH = "C:\Users\Lambda\flutter\bin;" + $env:PATH` then `flutter test` / `flutter analyze` / `flutter build apk --debug`. Regenerate drift code with `flutter pub run build_runner build --delete-conflicting-outputs` only if a `@DriftAccessor`/table changes (this plan adds **no** drift tables).
- Go: `$env:PATH = "C:\Program Files\Go\bin;" + $env:PATH`; `go test ./...` from `C:\Users\Lambda\Documents\heartbeat-server`.
- Schema for presence is ephemeral (no client drift bump). Server gets one additive SQLite column via an idempotent guard.

---

## Phase A — Server presence (`heartbeat-server`)

> Self-contained and backward-compatible. Deploy at end of Phase A; existing clients ignore the new endpoint. All paths below are under `C:\Users\Lambda\Documents\heartbeat-server`.

### Task A1: Hub tracks `last_seen` + a presence `Snapshot`

**Files:**
- Modify: `internal/signaling/hub.go`
- Test: `internal/signaling/hub_test.go`

- [ ] **Step 1: Write the failing test** — append to `internal/signaling/hub_test.go`:

```go
func TestHubTracksLastSeenAndSnapshot(t *testing.T) {
	h := NewHub()
	c := &fakeConn{}

	h.Add("alice", c)
	snap := h.Snapshot([]string{"alice", "bob"})

	if !snap["alice"].Online {
		t.Fatalf("alice should be online")
	}
	if snap["alice"].LastSeen.IsZero() {
		t.Fatalf("alice last_seen should be set on Add")
	}
	if snap["bob"].Online {
		t.Fatalf("bob never connected; should be offline")
	}
	if !snap["bob"].LastSeen.IsZero() {
		t.Fatalf("bob never seen; last_seen should be zero")
	}

	h.Remove("alice", c)
	snap = h.Snapshot([]string{"alice"})
	if snap["alice"].Online {
		t.Fatalf("alice removed; should be offline")
	}
	if snap["alice"].LastSeen.IsZero() {
		t.Fatalf("alice last_seen should persist after Remove")
	}
}
```

If `fakeConn` does not already exist in `hub_test.go`, reuse the existing one (the explorer confirmed it at `hub_test.go:70-83`). If absent, add:

```go
type fakeConn struct{ pushed [][]byte }

func (f *fakeConn) Push(env []byte, from string) error { f.pushed = append(f.pushed, env); return nil }
func (f *fakeConn) Close()                              {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/signaling/ -run TestHubTracksLastSeen -v`
Expected: FAIL — `h.Snapshot undefined` / `Presence` undefined.

- [ ] **Step 3: Implement minimal code** — edit `internal/signaling/hub.go`:

Add `"time"` to the import block. Replace the `Hub` struct + `NewHub` and extend `Add`/`Remove`, then add `Presence` + `Snapshot`:

```go
import (
	"sync"
	"time"
)

// Presence is a point-in-time liveness snapshot for one pubkey.
type Presence struct {
	Online   bool
	LastSeen time.Time // zero if never seen in this process
}

// Hub tracks online connections by pubkey-hex and relays send/deliver frames.
type Hub struct {
	mu       sync.RWMutex
	conns    map[string]Connection
	lastSeen map[string]time.Time
	// onSeen, if set, is invoked (pubkey, ts) on every connect/disconnect so
	// callers can persist last_seen durably. Never holds the hub lock.
	onSeen func(pubkey string, ts time.Time)
}

// NewHub constructs an empty Hub.
func NewHub() *Hub {
	return &Hub{
		conns:    make(map[string]Connection),
		lastSeen: make(map[string]time.Time),
	}
}

// SetOnSeen registers a durable-persistence callback for last_seen updates.
func (h *Hub) SetOnSeen(fn func(pubkey string, ts time.Time)) { h.onSeen = fn }
```

In `Add`, after `h.conns[pubkey] = c`, before unlocking — set last_seen and fire the callback after releasing the lock:

```go
func (h *Hub) Add(pubkey string, c Connection) {
	now := time.Now()
	h.mu.Lock()
	if old, ok := h.conns[pubkey]; ok {
		old.Close()
	}
	h.conns[pubkey] = c
	h.lastSeen[pubkey] = now
	fn := h.onSeen
	h.mu.Unlock()
	if fn != nil {
		fn(pubkey, now)
	}
}
```

In `Remove`, on a real delete, stamp last_seen + fire callback:

```go
func (h *Hub) Remove(pubkey string, c Connection) {
	now := time.Now()
	h.mu.Lock()
	var fire bool
	if cur, ok := h.conns[pubkey]; ok && cur == c {
		delete(h.conns, pubkey)
		h.lastSeen[pubkey] = now
		fire = true
	}
	fn := h.onSeen
	h.mu.Unlock()
	if fire && fn != nil {
		fn(pubkey, now)
	}
}
```

Add `Snapshot`:

```go
// Snapshot returns per-pubkey liveness for the requested pubkeys. Online is
// authoritative (from conns); LastSeen is this process's in-memory value and
// is zero if the pubkey was never seen since start.
func (h *Hub) Snapshot(pubkeys []string) map[string]Presence {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make(map[string]Presence, len(pubkeys))
	for _, pk := range pubkeys {
		_, online := h.conns[pk]
		out[pk] = Presence{Online: online, LastSeen: h.lastSeen[pk]}
	}
	return out
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/signaling/ -run TestHubTracksLastSeen -v`
Expected: PASS. Also run `go test ./internal/signaling/` to confirm no regressions.

- [ ] **Step 5: Commit**

```bash
git add internal/signaling/hub.go internal/signaling/hub_test.go
git commit -m "presence: hub tracks last_seen + Snapshot (A1)"
```

---

### Task A2: Phonebook `last_seen` column + Touch/LastSeenFor

**Files:**
- Modify: `internal/phonebook/store.go`
- Test: `internal/phonebook/store_test.go`

- [ ] **Step 1: Write the failing test** — append to `internal/phonebook/store_test.go` (if the file does not exist, create it with `package phonebook` and the standard imports `context`, `testing`):

```go
func TestLastSeenRoundTrip(t *testing.T) {
	s, err := Open("file:lastseen_test?mode=memory&cache=shared")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	ctx := context.Background()

	if err := s.TouchLastSeen(ctx, "alice", 1717160000); err != nil {
		t.Fatal(err)
	}
	if err := s.TouchLastSeen(ctx, "alice", 1717160500); err != nil { // newer wins
		t.Fatal(err)
	}
	m, err := s.LastSeenFor(ctx, []string{"alice", "bob"})
	if err != nil {
		t.Fatal(err)
	}
	if m["alice"] != 1717160500 {
		t.Fatalf("alice last_seen = %d, want 1717160500", m["alice"])
	}
	if _, ok := m["bob"]; ok {
		t.Fatalf("bob never touched; should be absent")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/phonebook/ -run TestLastSeenRoundTrip -v`
Expected: FAIL — `s.TouchLastSeen undefined`.

- [ ] **Step 3: Implement minimal code** — edit `internal/phonebook/store.go`:

Extend the `schema` const so fresh DBs have the column, AND add an idempotent migration for existing DBs in `Open` (existing prod DB has no `last_seen`). Replace the `Open` body's `db.Exec(schema)` block:

```go
const schema = `
CREATE TABLE IF NOT EXISTS phonebook (
	pubkey     TEXT PRIMARY KEY,
	fcm_token  TEXT NOT NULL,
	platform   TEXT NOT NULL,
	updated_at INTEGER NOT NULL,
	last_seen  INTEGER NOT NULL DEFAULT 0
);`

func Open(dsn string) (*Store, error) {
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if _, err := db.Exec(schema); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("init schema: %w", err)
	}
	if err := ensureLastSeenColumn(db); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("migrate last_seen: %w", err)
	}
	return &Store{db: db}, nil
}

// ensureLastSeenColumn adds last_seen to a pre-existing phonebook table that
// was created before this column existed. No-op when the column is present.
func ensureLastSeenColumn(db *sql.DB) error {
	rows, err := db.Query(`PRAGMA table_info(phonebook)`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dflt sql.NullString
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			return err
		}
		if name == "last_seen" {
			return nil // already present
		}
	}
	_, err = db.Exec(`ALTER TABLE phonebook ADD COLUMN last_seen INTEGER NOT NULL DEFAULT 0`)
	return err
}
```

Add the two methods at the end of `store.go`:

```go
// TouchLastSeen records that pubkeyHex was seen at unix-seconds ts. Only
// advances last_seen (newer wins); creates a placeholder row if the pubkey
// has no phonebook entry yet (e.g. connected but never FCM-registered).
func (s *Store) TouchLastSeen(ctx context.Context, pubkeyHex string, ts int64) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO phonebook (pubkey, fcm_token, platform, updated_at, last_seen)
		VALUES (?, '', '', 0, ?)
		ON CONFLICT(pubkey) DO UPDATE SET
			last_seen = MAX(phonebook.last_seen, excluded.last_seen)`,
		pubkeyHex, ts)
	return err
}

// LastSeenFor returns unix-seconds last_seen for each requested pubkey that
// has a row. Pubkeys with no row are omitted from the map.
func (s *Store) LastSeenFor(ctx context.Context, pubkeys []string) (map[string]int64, error) {
	out := make(map[string]int64, len(pubkeys))
	if len(pubkeys) == 0 {
		return out, nil
	}
	q := `SELECT pubkey, last_seen FROM phonebook WHERE pubkey IN (?` +
		strings.Repeat(",?", len(pubkeys)-1) + `)`
	args := make([]any, len(pubkeys))
	for i, pk := range pubkeys {
		args[i] = pk
	}
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var pk string
		var ls int64
		if err := rows.Scan(&pk, &ls); err != nil {
			return nil, err
		}
		out[pk] = ls
	}
	return out, rows.Err()
}
```

Add `"strings"` to the import block.

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/phonebook/ -v`
Expected: PASS (existing phonebook tests + the new one). The `Upsert` path still works because `last_seen` defaults to 0 and `Upsert` does not touch it.

- [ ] **Step 5: Commit**

```bash
git add internal/phonebook/store.go internal/phonebook/store_test.go
git commit -m "presence: phonebook last_seen column + Touch/LastSeenFor (A2)"
```

---

### Task A3: Persist last_seen on WS connect/disconnect

**Files:**
- Modify: `internal/signaling/handlers.go` (read it first — connect is ~line 78, deferred disconnect ~line 85)
- Modify: `cmd/heartbeat-server/main.go` (wire the callback)

- [ ] **Step 1: Wire the hub callback in `main.go`** — after `hub := signaling.NewHub()` (line 64), and after `book` is opened (it is, line 34), add:

```go
hub := signaling.NewHub()
hub.SetOnSeen(func(pubkey string, ts time.Time) {
	// Best-effort durable last_seen; a failed write just means the value
	// falls back to in-memory until the next connect/disconnect.
	if err := book.TouchLastSeen(context.Background(), pubkey, ts.Unix()); err != nil {
		log.Printf("[presence] touch_last_seen_err pub=%s err=%v", pubkey, err)
	}
})
```

(No change needed in `handlers.go` itself — the hub's `Add`/`Remove` already fire `onSeen`, and `handlers.go` already calls `hub.Add`/`hub.Remove`. Read `handlers.go` only to confirm those calls exist where the explorer said.)

- [ ] **Step 2: Verify it builds + existing tests pass**

Run: `go build ./... && go test ./...`
Expected: build OK, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add cmd/heartbeat-server/main.go
git commit -m "presence: persist last_seen via hub onSeen callback (A3)"
```

---

### Task A4: `internal/presence` package + `POST /v1/presence` handler

**Files:**
- Create: `internal/presence/handlers.go`
- Test: `internal/presence/handlers_test.go`

- [ ] **Step 1: Write the failing test** — create `internal/presence/handlers_test.go`. Mirror `internal/phonebook/handlers_test.go`'s `newAuthedRequest` helper (read it for the exact key-generation + signing helper; the canonical signed bytes are `ts + "\n" + body`). Then:

```go
package presence

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/sahitkogs/heartbeat-server/internal/auth"
	"github.com/sahitkogs/heartbeat-server/internal/signaling"
)

type fakeConn struct{}

func (fakeConn) Push(env []byte, from string) error { return nil }
func (fakeConn) Close()                             {}

func TestPresenceQuery(t *testing.T) {
	hub := signaling.NewHub()
	hub.Add("aa11", fakeConn{}) // online

	h := NewHandlers(hub, nil) // nil book → in-memory last_seen only
	body, _ := json.Marshal(PresenceRequest{Pubkeys: []string{"aa11", "bb22"}})

	// newAuthedRequest builds a signed POST (copy the helper from
	// internal/phonebook/handlers_test.go).
	req := newAuthedRequest(t, http.MethodPost, "/v1/presence", body)
	rec := httptest.NewRecorder()
	auth.RequireSignature(http.HandlerFunc(h.Query)).ServeHTTP(rec, req)

	if rec.Code != 200 {
		t.Fatalf("status = %d body=%s", rec.Code, rec.Body.String())
	}
	var resp PresenceResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if !resp.Presence["aa11"].Online {
		t.Fatalf("aa11 should be online")
	}
	if resp.Presence["bb22"].Online {
		t.Fatalf("bb22 should be offline")
	}
}

func TestPresenceUnsignedRejected(t *testing.T) {
	hub := signaling.NewHub()
	h := NewHandlers(hub, nil)
	body, _ := json.Marshal(PresenceRequest{Pubkeys: []string{"aa11"}})
	req := httptest.NewRequest(http.MethodPost, "/v1/presence", bytesReader(body))
	rec := httptest.NewRecorder()
	auth.RequireSignature(http.HandlerFunc(h.Query)).ServeHTTP(rec, req)
	if rec.Code == 200 {
		t.Fatalf("unsigned request should be rejected, got 200")
	}
}
```

(Use whatever body-reader helper `phonebook/handlers_test.go` uses — likely `bytes.NewReader`. Replace `bytesReader` accordingly.)

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/presence/ -v`
Expected: FAIL — package/types undefined.

- [ ] **Step 3: Implement** — create `internal/presence/handlers.go`:

```go
// Package presence answers batch liveness queries: for each requested
// pubkey, whether it currently holds a relay WS connection and when it was
// last seen. Online comes from the in-memory hub; last_seen falls back to
// the durable phonebook value across relay restarts.
package presence

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/sahitkogs/heartbeat-server/internal/auth"
	"github.com/sahitkogs/heartbeat-server/internal/signaling"
)

const maxPubkeys = 256

// LastSeenLookup is the slice of *phonebook.Store this package needs. Keeping
// it an interface lets tests pass nil and avoids an import cycle risk.
type LastSeenLookup interface {
	LastSeenFor(ctx context.Context, pubkeys []string) (map[string]int64, error)
}

type PresenceRequest struct {
	Pubkeys []string `json:"pubkeys"`
}

type Info struct {
	Online   bool  `json:"online"`
	LastSeen int64 `json:"last_seen"` // unix seconds; 0 = never
}

type PresenceResponse struct {
	Presence map[string]Info `json:"presence"`
}

type Handlers struct {
	Hub  *signaling.Hub
	Book LastSeenLookup // may be nil (tests / no durable fallback)
}

func NewHandlers(hub *signaling.Hub, book LastSeenLookup) *Handlers {
	return &Handlers{Hub: hub, Book: book}
}

// Query handles POST /v1/presence. Requires a valid signature (any signed
// client may ask about any pubkey — pubkeys are already shared on pairing).
func (h *Handlers) Query(w http.ResponseWriter, r *http.Request) {
	if auth.ClientPubkeyFromContext(r.Context()) == nil {
		http.Error(w, "no caller pubkey", http.StatusUnauthorized)
		return
	}
	var body PresenceRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "bad body", http.StatusBadRequest)
		return
	}
	if len(body.Pubkeys) == 0 || len(body.Pubkeys) > maxPubkeys {
		http.Error(w, "pubkeys: 1..256 required", http.StatusBadRequest)
		return
	}

	snap := h.Hub.Snapshot(body.Pubkeys)

	var durable map[string]int64
	if h.Book != nil {
		durable, _ = h.Book.LastSeenFor(r.Context(), body.Pubkeys) // best-effort
	}

	out := make(map[string]Info, len(body.Pubkeys))
	for _, pk := range body.Pubkeys {
		p := snap[pk]
		var ls int64
		if !p.LastSeen.IsZero() {
			ls = p.LastSeen.Unix()
		}
		if d := durable[pk]; d > ls {
			ls = d
		}
		out[pk] = Info{Online: p.Online, LastSeen: ls}
	}
	writeJSON(w, http.StatusOK, PresenceResponse{Presence: out})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/presence/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/presence/
git commit -m "presence: POST /v1/presence handler + tests (A4)"
```

---

### Task A5: Register route + version bump

**Files:**
- Modify: `cmd/heartbeat-server/main.go`

- [ ] **Step 1: Register the route** — after the wake handler registration (line 74), add:

```go
prHandlers := presence.NewHandlers(hub, book)
mux.Handle("/v1/presence", auth.RequireSignature(http.HandlerFunc(prHandlers.Query)))
```

Add `"github.com/sahitkogs/heartbeat-server/internal/presence"` to imports. Bump the version constant:

```go
const version = "0.3.0-presence"
```

- [ ] **Step 2: Verify build + full suite**

Run: `go build ./... && go test ./...`
Expected: build OK, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add cmd/heartbeat-server/main.go
git commit -m "presence: register /v1/presence route + bump version 0.3.0-presence (A5)"
```

---

### Task A6: Deploy + live verify

**Files:** none (ops). Use the `heartbeat-server-deploy` skill (distroless `scp` path — the e2-micro OOMs on full `docker build`).

- [ ] **Step 1: Deploy** the new binary/image per the skill. Then verify version:

Run: `curl http://34.42.231.29:8080/healthz`
Expected: JSON with `"version":"0.3.0-presence"`.

- [ ] **Step 2: Smoke the endpoint** with a signed request. Easiest path: after Phase B's `PresenceClient` exists, drive it from an emulator. For an immediate server-only smoke, use an existing signed-request helper or a throwaway Go script that signs `ts\n{"pubkeys":["<a known pubkey>"]}`. Confirm a 200 with a `presence` map. (If you defer this to Phase E, note it explicitly in the results doc.)

- [ ] **Step 3: Commit** (roadmap/tag deferred to Phase E). No code change here; record the deploy in the campaign results doc.

---

## Phase B — Client presence + green tick (`heart-beat-v3`)

> All paths under `C:\Users\Lambda\Documents\heart-beat-v3`. No drift schema change.

### Task B1: `PresenceClient`

**Files:**
- Create: `lib/services/presence_client.dart`
- Test: `test/services/presence_client_test.dart`

- [ ] **Step 1: Write the failing test** — create `test/services/presence_client_test.dart`. Mirror `test/services/phonebook_client_test.dart` (read it for the `MockClient` + signature-verify pattern). Core assertions:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:heartbeat_v3/services/presence_client.dart';
import 'package:heartbeat_v3/services/signing_service.dart';

void main() {
  test('fetchPresence parses online + last_seen', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'presence': {
            'aa11': {'online': true, 'last_seen': 1717160000},
            'bb22': {'online': false, 'last_seen': 0},
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final signing = SigningService.forTesting(); // see note below
    final client = PresenceClient(
      baseUri: Uri.parse('http://relay.test'),
      signing: signing,
      httpClient: mock,
    );

    final res = await client.fetchPresence(['aa11', 'bb22']);

    expect(captured.url.path, '/v1/presence');
    expect(captured.headers['X-Heartbeat-Pubkey'], isNotNull);
    expect(captured.headers['X-Heartbeat-Sig'], isNotNull);
    expect(res['aa11']!.online, isTrue);
    expect(res['aa11']!.lastSeen, isNotNull);
    expect(res['bb22']!.online, isFalse);
    expect(res['bb22']!.lastSeen, isNull); // 0 → null
  });
}
```

**Note:** use whatever `SigningService` test constructor the existing `phonebook_client_test.dart` / `wake_client_test.dart` use (they already build a test signer — copy that setup verbatim; do not invent `forTesting()` if it doesn't exist).

- [ ] **Step 2: Run test to verify it fails**

Run (set Flutter PATH first): `flutter test test/services/presence_client_test.dart`
Expected: FAIL — `PresenceClient`/`PresenceInfo` undefined.

- [ ] **Step 3: Implement** — create `lib/services/presence_client.dart` (mirrors `phonebook_client.dart` verbatim in signing/headers):

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/hex_codec.dart';
import 'signing_service.dart';

/// One peer's server-reported liveness.
class PresenceInfo {
  const PresenceInfo({required this.online, this.lastSeen});
  final bool online;
  final DateTime? lastSeen; // null when server reports last_seen == 0

  factory PresenceInfo.fromJson(Map<String, dynamic> j) {
    final ls = (j['last_seen'] as num?)?.toInt() ?? 0;
    return PresenceInfo(
      online: j['online'] == true,
      lastSeen: ls > 0 ? DateTime.fromMillisecondsSinceEpoch(ls * 1000, isUtc: true) : null,
    );
  }
}

/// Queries the relay's signed `POST /v1/presence`. Signature contract matches
/// PhonebookClient: Ed25519 over `"<rfc3339 ts>\n<body>"`.
class PresenceClient {
  PresenceClient({
    required this.baseUri,
    required this.signing,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final SigningService signing;
  final http.Client _http;

  /// Returns presence per requested pubkey. On any network/server error
  /// returns an empty map (caller keeps last-known state).
  Future<Map<String, PresenceInfo>> fetchPresence(List<String> pubkeysHex) async {
    if (pubkeysHex.isEmpty) return const {};
    final body = jsonEncode({'pubkeys': pubkeysHex});
    final ts = _rfc3339Now();
    final pubHex = await signing.publicKeyHex();
    final sig = await signing.sign(utf8.encode('$ts\n$body'));
    final url = baseUri.resolve('/v1/presence');

    final http.Response resp;
    try {
      resp = await _http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Heartbeat-Pubkey': pubHex,
          'X-Heartbeat-Sig': bytesToHex(sig),
          'X-Heartbeat-Timestamp': ts,
        },
        body: body,
      );
    } catch (e) {
      _log('fetch network error: $e');
      return const {};
    }
    if (resp.statusCode != 200) {
      _log('fetch failed status=${resp.statusCode}');
      return const {};
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final map = (decoded['presence'] as Map<String, dynamic>? ?? {});
    return map.map((k, v) =>
        MapEntry(k, PresenceInfo.fromJson(v as Map<String, dynamic>)));
  }

  void dispose() => _http.close();

  static String _rfc3339Now() {
    final now = DateTime.now().toUtc();
    final iso = now.toIso8601String();
    final m = RegExp(r'^(.+?)(?:\.\d+)?(Z)$').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(1)}${m.group(2)}';
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[Presence] $msg');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/presence_client_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/presence_client.dart test/services/presence_client_test.dart
git commit -m "presence: PresenceClient signed /v1/presence call (B1)"
```

---

### Task B2: `PresenceStatus` 3-state derivation

**Files:**
- Create: `lib/features/presence/presence_status.dart`
- Test: `test/features/presence/presence_status_test.dart`

- [ ] **Step 1: Write the failing test** — create `test/features/presence/presence_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heartbeat_v3/services/presence_client.dart';
import 'package:heartbeat_v3/features/presence/presence_status.dart';

void main() {
  final now = DateTime.utc(2026, 5, 31, 12, 0, 0);

  test('online when server says online', () {
    final s = presenceStatusFor(const PresenceInfo(online: true), now);
    expect(s, PresenceStatus.online);
  });

  test('recent when seen within 24h', () {
    final s = presenceStatusFor(
        PresenceInfo(online: false, lastSeen: now.subtract(const Duration(hours: 5))), now);
    expect(s, PresenceStatus.recent);
  });

  test('stale when seen over 24h ago', () {
    final s = presenceStatusFor(
        PresenceInfo(online: false, lastSeen: now.subtract(const Duration(days: 3))), now);
    expect(s, PresenceStatus.stale);
  });

  test('stale when never seen', () {
    final s = presenceStatusFor(const PresenceInfo(online: false), now);
    expect(s, PresenceStatus.stale);
  });

  test('unknown when no presence info at all', () {
    expect(presenceStatusFor(null, now), PresenceStatus.unknown);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/presence/presence_status_test.dart`
Expected: FAIL — undefined.

- [ ] **Step 3: Implement** — create `lib/features/presence/presence_status.dart`:

```dart
import '../../services/presence_client.dart';

/// Reachability tiers rendered as the green tick. NOT identity verification.
enum PresenceStatus { online, recent, stale, unknown }

/// Window after last_seen during which a non-online contact still counts as
/// "recent" (amber) rather than "stale" (grey).
const Duration recentWindow = Duration(hours: 24);

PresenceStatus presenceStatusFor(PresenceInfo? info, DateTime now) {
  if (info == null) return PresenceStatus.unknown;
  if (info.online) return PresenceStatus.online;
  final ls = info.lastSeen;
  if (ls == null) return PresenceStatus.stale;
  return now.toUtc().difference(ls.toUtc()) <= recentWindow
      ? PresenceStatus.recent
      : PresenceStatus.stale;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/presence/presence_status_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/presence/presence_status.dart test/features/presence/presence_status_test.dart
git commit -m "presence: 3-state PresenceStatus derivation (B2)"
```

---

### Task B3: Presence state provider + foreground poller

**Files:**
- Create: `lib/features/presence/presence_provider.dart`
- Test: `test/features/presence/presence_poller_test.dart`
- Read first: `lib/theme/theme_mode_provider.dart` (match its StateNotifier/Notifier style), `lib/features/contacts/contacts_provider.dart`, `lib/features/chat/message_service_provider.dart`.

- [ ] **Step 1: Write the failing test** — create `test/features/presence/presence_poller_test.dart`. The poller's pollable core is a pure function we can test without timers: given previous state + a fresh fetch, it returns the new state and the set of pubkeys that transitioned **to online**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heartbeat_v3/services/presence_client.dart';
import 'package:heartbeat_v3/features/presence/presence_provider.dart';

void main() {
  test('detects offline/stale->online transitions', () {
    final prev = <String, PresenceInfo>{
      'aa': PresenceInfo(online: false),
      'bb': PresenceInfo(online: true),
    };
    final next = <String, PresenceInfo>{
      'aa': PresenceInfo(online: true),  // transitioned UP
      'bb': PresenceInfo(online: true),  // stayed online
      'cc': PresenceInfo(online: true),  // newly seen online
    };
    final ups = newlyOnline(prev, next);
    expect(ups, containsAll(<String>['aa', 'cc']));
    expect(ups.contains('bb'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/presence/presence_poller_test.dart`
Expected: FAIL — `newlyOnline`/`presence_provider.dart` undefined.

- [ ] **Step 3: Implement** — create `lib/features/presence/presence_provider.dart`. Use the same Riverpod style as `theme_mode_provider.dart` (StateNotifier shown here; adapt if the project uses `Notifier`):

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/presence_client.dart';
import '../contacts/contacts_provider.dart';
import '../chat/message_service_provider.dart';

/// Pure helper (unit-tested): pubkeys that became online since the last poll.
Set<String> newlyOnline(
    Map<String, PresenceInfo> prev, Map<String, PresenceInfo> next) {
  final ups = <String>{};
  next.forEach((pk, info) {
    if (info.online && (prev[pk]?.online ?? false) == false) ups.add(pk);
  });
  return ups;
}

/// Ephemeral presence map keyed by pubkey hex. Never persisted.
class PresenceNotifier extends StateNotifier<Map<String, PresenceInfo>> {
  PresenceNotifier(this._ref) : super(const {});

  final Ref _ref;
  Timer? _timer;
  static const pollInterval = Duration(seconds: 25);

  /// Called when the app enters the foreground. Polls immediately, then on
  /// an interval.
  void startPolling() {
    _timer ??= Timer.periodic(pollInterval, (_) => pollOnce());
    pollOnce();
  }

  /// Called when the app backgrounds. Stops the data/battery drain.
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> pollOnce() async {
    final contacts = await _ref.read(contactsListProvider.future);
    if (contacts.isEmpty) return;
    final pubkeys = contacts.map((c) => c.pubkeyHex).toList();

    final client = _ref.read(presenceClientProvider);
    final fresh = await client.fetchPresence(pubkeys);
    if (fresh.isEmpty) return; // network error → keep last-known

    final ups = newlyOnline(state, fresh);
    state = {...state, ...fresh};

    // Reliability core: a contact just became reachable → flush anything
    // stranded in their outbox. Fire-and-forget; flush is idempotent.
    if (ups.isNotEmpty) {
      final ms = await _ref.read(messageServiceProvider.future);
      for (final pk in ups) {
        unawaited(ms.flushPeerOnReachable(pk));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final presenceClientProvider = Provider<PresenceClient>((ref) {
  // Reuse the relay base URL + signing the other clients use. Match how
  // phonebookClientProvider / wakeClientProvider build theirs.
  throw UnimplementedError(
      'wire baseUri + signing exactly like phonebookClientProvider in '
      'lib/features/notifications/fcm_provider.dart');
});

final presenceProvider =
    StateNotifierProvider<PresenceNotifier, Map<String, PresenceInfo>>(
        (ref) => PresenceNotifier(ref));
```

**Wire `presenceClientProvider` for real:** open `lib/features/notifications/fcm_provider.dart`, find how `phonebookClientProvider` constructs `PhonebookClient(baseUri: Uri.parse(relayHttpBaseUrl), signing: ...)`, and build `PresenceClient` the same way. Replace the `throw UnimplementedError(...)` body. (`ms.flushPeerOnReachable` is added in Task C3 — until then this references a method that does not yet exist; implement Phase C before running the app, or temporarily stub the call. The unit test above does not touch the notifier, so it passes now.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/presence/presence_poller_test.dart`
Expected: PASS (the test only exercises `newlyOnline`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/presence/presence_provider.dart test/features/presence/presence_poller_test.dart
git commit -m "presence: presence provider + foreground poller + newlyOnline (B3)"
```

---

### Task B4: `PresenceBadge` widget

**Files:**
- Create: `lib/features/presence/presence_badge.dart`
- Read first: `lib/theme/app_colors.dart` (confirm `AppColors.green`), `lib/features/chat/chat_list_screen.dart` for the dimmed-text alpha pattern.

- [ ] **Step 1: Implement** (UI widget; verified by visual check in Phase E, no unit test):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'presence_provider.dart';
import 'presence_status.dart';

/// Small reachability dot next to a contact's name. Green = online,
/// amber = seen within 24h, hollow grey = stale, nothing = unknown.
class PresenceBadge extends ConsumerWidget {
  const PresenceBadge({super.key, required this.pubkeyHex, this.size = 10});

  final String pubkeyHex;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(presenceProvider)[pubkeyHex];
    final status = presenceStatusFor(info, DateTime.now());
    if (status == PresenceStatus.unknown) {
      return SizedBox(width: size, height: size);
    }
    final onSurface = Theme.of(context).colorScheme.onSurface;
    switch (status) {
      case PresenceStatus.online:
        return _dot(AppColors.green, filled: true);
      case PresenceStatus.recent:
        return _dot(const Color(0xFFC8862B), filled: true); // amber
      case PresenceStatus.stale:
        return _dot(onSurface.withValues(alpha: 0.35), filled: false);
      case PresenceStatus.unknown:
        return SizedBox(width: size, height: size);
    }
  }

  Widget _dot(Color color, {required bool filled}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.5),
        ),
      );
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/presence/presence_badge.dart`
Expected: no errors (the existing `lib/core/hex_codec.dart:1:1` baseline info is unrelated).

- [ ] **Step 3: Commit**

```bash
git add lib/features/presence/presence_badge.dart
git commit -m "presence: PresenceBadge 3-state dot widget (B4)"
```

---

### Task B5: Place the badge on the 4 surfaces

**Files (modify, after reading each to find the exact name `Row`/`Text`):**
- `lib/features/chat/chat_list_screen.dart` — direct tile title (`_buildDirectTile`, ~line 290). Wrap the title in a `Row(children: [Flexible(child: Text(title...)), const SizedBox(width: 6), PresenceBadge(pubkeyHex: pk)])`. **Skip group tiles.**
- `lib/features/contacts/contacts_screen.dart` — `ListTile` title (~line 50). Same Row treatment with `c.pubkeyHex`.
- `lib/features/chat/select_contact_screen.dart` — contact row title (~line 94). Same with `c.pubkeyHex`.
- `lib/features/chat/chat_thread_screen.dart` — header title row (~line 144, direct chats only). Add `PresenceBadge(pubkeyHex: widget.chatId)` next to the name, and a subtitle line: `online` / `last seen …` from `ref.watch(presenceProvider)[widget.chatId]` formatted via a small `lastSeenLabel(info)` helper (put the helper in `presence_status.dart`).

- [ ] **Step 1: Add `lastSeenLabel`** to `lib/features/presence/presence_status.dart`:

```dart
String lastSeenLabel(PresenceInfo? info, DateTime now) {
  if (info == null) return '';
  if (info.online) return 'online';
  final ls = info.lastSeen;
  if (ls == null) return 'last seen never';
  final d = now.toUtc().difference(ls.toUtc());
  if (d.inMinutes < 1) return 'last seen just now';
  if (d.inMinutes < 60) return 'last seen ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'last seen ${d.inHours}h ago';
  return 'last seen ${d.inDays}d ago';
}
```

- [ ] **Step 2: Edit the 4 surfaces** as described above (import `presence_badge.dart` and, for the header, `presence_status.dart`). Each screen is already a `ConsumerWidget`/`ConsumerStatefulWidget`, so `PresenceBadge` (itself a `ConsumerWidget`) drops in directly.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean apart from the pre-existing `lib/core/hex_codec.dart:1:1` info.

- [ ] **Step 4: Commit**

```bash
git add lib/features/presence/presence_status.dart lib/features/chat/chat_list_screen.dart lib/features/contacts/contacts_screen.dart lib/features/chat/select_contact_screen.dart lib/features/chat/chat_thread_screen.dart
git commit -m "presence: green-tick badge on chat list, contacts, picker, thread header (B5)"
```

---

### Task B6: Lifecycle wiring — poll only while foregrounded

**Files:**
- Modify: `lib/main.dart` (the `_HeartbeatV3AppState.didChangeAppLifecycleState` block + initState)

- [ ] **Step 1: Start/stop the poller on lifecycle** — in `didChangeAppLifecycleState`, alongside the existing `resumed` invalidations, add:

```dart
if (state == AppLifecycleState.resumed) {
  // ...existing invalidations...
  ref.read(presenceProvider.notifier).startPolling();
} else if (state == AppLifecycleState.paused) {
  ref.read(presenceProvider.notifier).stopPolling();
}
```

Also kick an initial poll once the first frame is up (so a cold foreground start polls without waiting for a lifecycle event). In `initState`'s post-frame callback (or wherever `ChatListScreen` mounts), call `ref.read(presenceProvider.notifier).startPolling();`. Import `features/presence/presence_provider.dart`.

- [ ] **Step 2: Verify** the app builds.

Run: `flutter build apk --debug`
Expected: build succeeds (this also confirms `flushPeerOnReachable` exists — so do Phase C first, or land B6 after C3).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "presence: start/stop foreground poller on app lifecycle (B6)"
```

---

## Phase C — Reliability: stale→online outbox flush

> This is the point of the feature. Land C before running the app from Phase B (B3/B6 reference `flushPeerOnReachable`).

### Task C1: `OutboxDao.kickPeer`

**Files:**
- Modify: `lib/data/outbox_dao.dart`
- Test: `test/data/outbox_dao_test.dart`

- [ ] **Step 1: Write the failing test** — append to `test/data/outbox_dao_test.dart` (mirror its existing in-memory DB setup):

```dart
test('kickPeer resets nextRetryAt to now for that peer only', () async {
  final future = DateTime.now().add(const Duration(hours: 1));
  await dao.insert(
    msgId: 'm1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
    createdAt: DateTime.now(), nextRetryAt: future,
  );
  await dao.insert(
    msgId: 'm2', peerPubkeyHex: 'peerB', envelopeBytes: [2],
    createdAt: DateTime.now(), nextRetryAt: future,
  );

  final now = DateTime.now();
  final kicked = await dao.kickPeer('peerA', now);
  expect(kicked, 1);

  final due = await dao.dueBefore(now.add(const Duration(seconds: 1)));
  expect(due.map((r) => r.msgId), contains('m1'));
  expect(due.map((r) => r.msgId), isNot(contains('m2')));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/outbox_dao_test.dart`
Expected: FAIL — `dao.kickPeer` undefined.

- [ ] **Step 3: Implement** — add to `lib/data/outbox_dao.dart`:

```dart
/// Sets `nextRetryAt = now` for every outbox row addressed to
/// [peerPubkeyHex], pulling them into the next retransmit sweep immediately.
/// Returns the number of rows kicked. Used by the presence-triggered flush
/// when a peer transitions to online.
Future<int> kickPeer(String peerPubkeyHex, DateTime now) async {
  return (update(outbox)..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
      .write(OutboxCompanion(nextRetryAt: Value(now)));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/outbox_dao_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/outbox_dao.dart test/data/outbox_dao_test.dart
git commit -m "reliability: OutboxDao.kickPeer for presence-triggered flush (C1)"
```

---

### Task C2: `OutboxRetransmitter.flushForPeer`

**Files:**
- Modify: `lib/chat/outbox_retransmitter.dart`
- Test: `test/chat/outbox_retransmitter_test.dart`

- [ ] **Step 1: Write the failing test** — append to `test/chat/outbox_retransmitter_test.dart` (reuse its fake sender + `seed` helper). Seed a row for `peerA` with `nextRetryAt` far in the future, assert a normal sweep does NOT send it, then `flushForPeer('peerA')` and assert the fake sender received it:

```dart
test('flushForPeer retransmits a not-yet-due row immediately', () async {
  final future = DateTime.now().add(const Duration(hours: 1));
  await seed(msgId: 'm1', peer: 'peerA', nextRetryAt: future); // helper exists
  // Future-due row is not picked up by a present-time sweep.
  await retransmitter.sweepOnceForTest(now: DateTime.now());
  expect(sender.sent, isEmpty);

  await retransmitter.flushForPeer('peerA');
  expect(sender.sent.map((c) => c.peer), contains('peerA'));
});
```

(If the existing `seed` helper has a different signature, adapt the call to match — read the test file first.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/chat/outbox_retransmitter_test.dart`
Expected: FAIL — `flushForPeer` undefined.

- [ ] **Step 3: Implement** — add to `lib/chat/outbox_retransmitter.dart`:

```dart
/// Presence-triggered flush: kick every pending row for [peerPubkeyHex] to
/// due-now, then run one sweep so they go out immediately. Safe to call
/// repeatedly — the sweep + receipt dedup prevents duplicate delivery.
Future<void> flushForPeer(String peerPubkeyHex) async {
  final now = DateTime.now();
  final kicked = await outbox.kickPeer(peerPubkeyHex, now);
  if (kicked == 0) return;
  // ignore: avoid_print
  print('[OR] flush_for_peer peer=$peerPubkeyHex kicked=$kicked');
  await _sweepAt(now);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/chat/outbox_retransmitter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/chat/outbox_retransmitter.dart test/chat/outbox_retransmitter_test.dart
git commit -m "reliability: OutboxRetransmitter.flushForPeer (C2)"
```

---

### Task C3: `MessageService.flushPeerOnReachable`

**Files:**
- Modify: `lib/chat/message_service.dart` (read it to find where it holds its `OutboxRetransmitter` — it constructs/owns one; the explorer noted retransmit wiring in this file)
- Test: `test/chat/message_service_test.dart`

- [ ] **Step 1: Write the failing test** — append to `test/chat/message_service_test.dart` (reuse its `_FakeRelay`/setup). Assert that calling `flushPeerOnReachable('peerA')` triggers a retransmit of a stranded row (seed an outbox row for peerA with a far-future retry, then call, then assert the fake relay/sender saw the send):

```dart
test('flushPeerOnReachable retransmits stranded outbox rows', () async {
  // Seed a pending outbox row for peerA with nextRetryAt far in the future
  // (use the same outbox DAO the service uses in the test harness).
  // ...seed...
  await service.flushPeerOnReachable('peerA');
  // Assert the fake relay/sender recorded a send to peerA.
  expect(relay.sent.where((f) => f.to == 'peerA'), isNotEmpty);
});
```

(Match the test harness's existing seeding + fake-relay accessor names; read the file first.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/chat/message_service_test.dart`
Expected: FAIL — `flushPeerOnReachable` undefined.

- [ ] **Step 3: Implement** — add a thin delegator to `MessageService` that forwards to its retransmitter:

```dart
/// Called by the presence poller when [peerPubkeyHex] transitions to online.
/// Flushes any stranded outbox messages to that peer.
Future<void> flushPeerOnReachable(String peerPubkeyHex) =>
    _retransmitter.flushForPeer(peerPubkeyHex);
```

(Use the actual field name `MessageService` uses for its `OutboxRetransmitter` — read the file; it may be `_retransmitter`, `_outboxRetransmitter`, etc.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/chat/message_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Full client suite + analyze**

Run: `flutter test` then `flutter analyze`
Expected: all pass (~257 + new tests); analyze clean apart from the baseline info.

- [ ] **Step 6: Commit**

```bash
git add lib/chat/message_service.dart test/chat/message_service_test.dart
git commit -m "reliability: MessageService.flushPeerOnReachable delegates to retransmitter (C3)"
```

---

## Phase D — Records integrity + diagnostics

### Task D1: `IntegrityReport` computation

**Files:**
- Create: `lib/features/diagnostics/integrity_report.dart`
- Test: `test/features/diagnostics/integrity_report_test.dart`
- Read first: `lib/data/chats_dao.dart` (DeliveryState enum + message/chat query methods), `lib/data/outbox_dao.dart`.

- [ ] **Step 1: Write the failing test** — create `test/features/diagnostics/integrity_report_test.dart` with an in-memory `AppDatabase` (mirror `outbox_dao_test.dart` setup). Seed:
  - one outbox row with `createdAt` 25h ago, still present → expect `stuckOutbox == 1`;
  - one message marked `sent` with no outbox row and no receipt → expect `orphanedSent == 1`;
  - assert a clean DB yields all-zero counts.

```dart
test('flags stuck outbox + orphaned sent, clean otherwise', () async {
  // clean
  var rep = await computeIntegrityReport(db);
  expect(rep.stuckOutbox, 0);
  expect(rep.orphanedSent, 0);

  // stuck: outbox row older than maxAge still pending
  await outboxDao.insert(
    msgId: 's1', peerPubkeyHex: 'p', envelopeBytes: [1],
    createdAt: DateTime.now().subtract(const Duration(hours: 25)),
    nextRetryAt: DateTime.now(),
  );
  rep = await computeIntegrityReport(db);
  expect(rep.stuckOutbox, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/diagnostics/integrity_report_test.dart`
Expected: FAIL — undefined.

- [ ] **Step 3: Implement** — create `lib/features/diagnostics/integrity_report.dart`:

```dart
import '../../data/app_database.dart';
import '../../data/outbox_dao.dart';
import '../../chat/outbox_retransmitter.dart' show OutboxRetransmitter;

/// Read-only audit of message-delivery records. Serves "every record is kept":
/// surfaces messages that may have been lost or left unconfirmed.
class IntegrityReport {
  const IntegrityReport({
    required this.stuckOutbox,
    required this.orphanedSent,
    required this.stuckPeers,
  });

  /// Outbox rows older than the 24h expiry still sitting pending.
  final int stuckOutbox;

  /// Messages we marked `sent` with no live outbox row and no delivery
  /// receipt — sent into the void, unconfirmed.
  final int orphanedSent;

  /// Distinct peer pubkeys that own at least one stuck outbox row (re-kick
  /// targets).
  final List<String> stuckPeers;

  bool get isClean => stuckOutbox == 0 && orphanedSent == 0;
}

Future<IntegrityReport> computeIntegrityReport(AppDatabase db) async {
  final now = DateTime.now();
  final cutoff = now.subtract(OutboxRetransmitter.maxAge);

  // Stuck outbox: rows whose createdAt is older than the expiry window but
  // are still present (the sweeper should have expired them; if they linger
  // the sweeper isn't running or the row keeps failing).
  final allOutbox = await db.outboxDao.dueBefore(now.add(const Duration(days: 365)));
  final stuck = allOutbox.where((r) => r.createdAt.isBefore(cutoff)).toList();
  final stuckPeers = <String>{for (final r in stuck) r.peerPubkeyHex}.toList();

  // Orphaned sent: query via ChatsDao. Use the existing DeliveryState enum +
  // a messages query. If no direct DAO method exists, add a small
  // `messagesInState(DeliveryState)` to ChatsDao and cross-check against
  // outbox msgIds.
  final orphanedSent = await db.chatsDao.countOrphanedSent(); // add in ChatsDao

  return IntegrityReport(
    stuckOutbox: stuck.length,
    orphanedSent: orphanedSent,
    stuckPeers: stuckPeers,
  );
}
```

**Add `countOrphanedSent()` to `lib/data/chats_dao.dart`:** counts messages whose `deliveryState == sent` and whose `msgId` is NOT in the `outbox` table (i.e. no retry pending) — meaning the send was never confirmed delivered nor is being retried. Implement with a drift `customSelect` or a left-join; read the DeliveryState column name in `chats_dao.dart` first. Cover it with a quick DAO test if practical.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/diagnostics/integrity_report_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/diagnostics/integrity_report.dart lib/data/chats_dao.dart test/features/diagnostics/integrity_report_test.dart
git commit -m "reliability: records-integrity report (stuck/orphaned) (D1)"
```

---

### Task D2: Diagnostics screen + re-kick action

**Files:**
- Create: `lib/features/diagnostics/diagnostics_screen.dart`
- Modify: `lib/features/identity/identity_screen.dart` (the "My profile" screen — add a low-key "Diagnostics" row)
- Modify: route table in `lib/main.dart` if it uses named routes (else push directly).

- [ ] **Step 1: Implement the screen** (ConsumerStatefulWidget): on open, `computeIntegrityReport(db)`; show counts per category; a button "Re-kick stuck outbox" that, for each `stuckPeers` entry, calls `ms.flushPeerOnReachable(pk)` then recomputes. No automatic mutation. Match the visual style of `identity_screen.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart'; // appDatabaseProvider
import '../chat/message_service_provider.dart';
import 'integrity_report.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  IntegrityReport? _report;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider); // confirm provider name
    final r = await computeIntegrityReport(db);
    if (mounted) setState(() { _report = r; _busy = false; });
  }

  Future<void> _reKick() async {
    final r = _report;
    if (r == null || r.stuckPeers.isEmpty) return;
    setState(() => _busy = true);
    final ms = await ref.read(messageServiceProvider.future);
    for (final pk in r.stuckPeers) {
      await ms.flushPeerOnReachable(pk);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: _busy && r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              ListTile(title: const Text('Stuck outbox'), trailing: Text('${r?.stuckOutbox ?? '-'}')),
              ListTile(title: const Text('Orphaned sent'), trailing: Text('${r?.orphanedSent ?? '-'}')),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: (r?.stuckPeers.isEmpty ?? true) || _busy ? null : _reKick,
                  child: const Text('Re-kick stuck outbox'),
                ),
              ),
            ]),
    );
  }
}
```

(Confirm `appDatabaseProvider` is the real provider name — read `lib/data/app_database.dart` / its provider. Adapt if different.)

- [ ] **Step 2: Add the entry point** — in `identity_screen.dart` ("My profile") add a `ListTile(title: Text('Diagnostics'), onTap: () => Navigator.push(... DiagnosticsScreen()))` near the theme toggle.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter build apk --debug`
Expected: clean + builds.

- [ ] **Step 4: Commit**

```bash
git add lib/features/diagnostics/diagnostics_screen.dart lib/features/identity/identity_screen.dart lib/main.dart
git commit -m "reliability: diagnostics screen + re-kick action (D2)"
```

---

## Phase E — Test-plan doc + 3-emulator campaign

### Task E1: Write the emulator E2E test-plan catalog

**Files:**
- Create: `docs/2026-05-31-emulator-e2e-test-plan.md`

- [ ] **Step 1: Author the catalog.** Include, as a numbered case list with explicit setup / action / expected / pass-criteria columns, the families from the design §8.2. At minimum:
  - **Delivery matrix** (sender state × receiver state ∈ {foreground, backgrounded, swipe-killed (NOT force-stop), force-stop+manual-relaunch, emulator-offline-then-online}); each asserts the message arrives AND is persisted on both ends.
  - **Presence:** badge shows online/recent/stale correctly; transition repaints within one poll (~25s); thread header "last seen" text correct.
  - **Reliability flush:** send to an offline peer → no immediate delivery → bring peer online → message delivered with NO manual resend (the core test); ticks correct; no duplicate.
  - **Groups (3 emulators):** create, add member, remove member, leave, group text fan-out, offline group member receives on return.
  - **Persistence:** force-stop + relaunch preserves chats/messages/group state; clear-data + re-pair re-registers + resumes.
  - **Records integrity:** strand a message (peer offline + kill sender's retransmit window artificially or send to a never-online peer), open Diagnostics, confirm it's flagged, re-kick recovers it.
  - **Adversarial:** emulator dropped mid-send; relay reconnect; rapid online/offline flap doesn't double-send.
  - Each row references the relevant logcat filters from the `heart-beat-v3-deploy` skill and the server `[ws]`/`[presence]` log lines.
- [ ] **Step 2: Commit**

```bash
git add docs/2026-05-31-emulator-e2e-test-plan.md
git commit -m "docs: emulator E2E reliability test-plan catalog (E1)"
```

---

### Task E2: Provision 3 emulators + install

**Files:** none (ops).

- [ ] **Step 1: Create a 3rd AVD.** Existing AVDs: `Heartbeat`, `Heartbeat2` (Google-Play images, FCM-capable). Create `Heartbeat3` from the same system image:

```powershell
$avd = "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
& $avd create avd -n Heartbeat3 -k "<same system-image package as Heartbeat>" -d pixel_6
```

(Read the package id from `& $avd list avd` output for `Heartbeat`. Must be a `google_apis_playstore` image so FCM works.)

- [ ] **Step 2: Boot all three** (separate ports) and confirm `adb devices` shows three:

```powershell
$emu = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
Start-Process $emu -ArgumentList '-avd','Heartbeat','-port','5554'
Start-Process $emu -ArgumentList '-avd','Heartbeat2','-port','5556'
Start-Process $emu -ArgumentList '-avd','Heartbeat3','-port','5558'
```

- [ ] **Step 3: Build + install** the debug APK (which now includes presence) on all three via `adb -s emulator-5554/5556/5558 install -r <apk>`. Launch each. Onboard a distinct display name per emulator; pair all three pairwise via paste-pubkey.

- [ ] **Step 4:** No commit (ops). Record the device map (emulator → port → pubkey → display name) at the top of the results doc in E3.

---

### Task E3: Run the campaign + log findings

**Files:**
- Create: `docs/2026-05-31-emulator-e2e-results.md`

- [ ] **Step 1: Execute every case** in the E1 catalog across the 3 emulators using the `heart-beat-v3-deploy` loop (build/install/launch/screencap/read; tap coords via screenshot + scale). Tail client `[MS]/[Relay]/[BG]` and server `[ws]/[presence]` logs side-by-side. **Use swipe-from-recents for "natural kill"** (force-stop suppresses FCM — reserve it for the explicit force-stop case).
- [ ] **Step 2: Record each result** in `docs/2026-05-31-emulator-e2e-results.md`: case id, PASS/FAIL, evidence (log excerpt / screenshot path), and for failures a **severity** graded against the central goal — `CRITICAL` (a message was not delivered or a record was lost), `HIGH` (delivered but wrong state/duplicate), `MEDIUM` (UX/timing), `LOW` (cosmetic). **Fix nothing this session** — log only.
- [ ] **Step 3: Summarize** at the top: total cases, pass rate, count of CRITICAL/HIGH, and a "follow-up tasks" list (each CRITICAL/HIGH becomes a future task).
- [ ] **Step 4: Commit**

```bash
git add docs/2026-05-31-emulator-e2e-results.md
git commit -m "docs: 3-emulator reliability campaign results (E3)"
```

---

### Task E4: Wrap-up — version, roadmap, memory

**Files:**
- Modify: `pubspec.yaml` (version bump), `C:\Users\Lambda\Documents\heart-beat\docs\heartbeat-roadmap.md` (status row), server `cmd/heartbeat-server/main.go` already bumped in A5.

- [ ] **Step 1: Bump client version** in `pubspec.yaml` (e.g. `1.1.0+11`) and **tag** per convention after the suite is green and the campaign logged. Tag client `vX.Y.Z-presence` and server `0.3.0-presence`.
- [ ] **Step 2: Update the roadmap** — add a phase row (e.g. `10.4.4 — presence + reliability`) summarizing what shipped, the server `0.3.0-presence` deploy, and a pointer to the results doc + its CRITICAL/HIGH follow-ups.
- [ ] **Step 3: Write/update a deployed-memory** note (per project convention) with the presence re-verify procedure + the 3-emulator setup.
- [ ] **Step 4: Commit + push** (ask the user before pushing/tagging if not pre-authorized).

```bash
git add pubspec.yaml
git commit -m "release: presence + reliability (E4)"
```

---

## Self-review checklist (done while writing)

- **Spec coverage:** server last_seen (A1–A3) ✓, /v1/presence (A4–A5) ✓, deploy (A6) ✓, PresenceClient (B1) ✓, 3-state derivation (B2) ✓, poller foreground-only (B3, B6) ✓, badge on 4 surfaces (B4–B5) ✓, stale→online flush (B3→C1–C3) ✓, records integrity + diagnostics (D1–D2) ✓, test-plan doc + 3-emulator campaign, findings logged only (E1–E3) ✓, wrap-up/versioning (E4) ✓, privacy note (design §9) acknowledged as out-of-scope ✓.
- **Ordering caveat (flagged in-plan):** B3/B6 reference `MessageService.flushPeerOnReachable` (C3) and `presenceClientProvider` wiring — land Phase C and wire the provider before running the app; the Phase B unit tests do not depend on either, so they pass in isolation.
- **Type consistency:** `PresenceInfo{online,lastSeen}`, `PresenceStatus{online,recent,stale,unknown}`, `presenceStatusFor`, `newlyOnline`, `kickPeer`, `flushForPeer`, `flushPeerOnReachable`, server `Presence{Online,LastSeen}` / `Snapshot` / `Info{Online,LastSeen}` / `PresenceResponse{Presence}` — used consistently across tasks.
- **Open verifications the executor must do (noted at point of use):** exact `SigningService` test constructor; `theme_mode_provider` Riverpod style; `MessageService`'s retransmitter field name; `appDatabaseProvider` name; `ChatsDao` DeliveryState column + `countOrphanedSent` query; `phonebook/handlers_test.go` `newAuthedRequest` helper; `signaling/handlers.go` Add/Remove call sites; the exact Google-Play system-image package for the 3rd AVD.
