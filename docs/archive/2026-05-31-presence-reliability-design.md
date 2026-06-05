# Presence (Green Tick) + Reliability + 3-Emulator Campaign — Design

> **Status:** design approved 2026-05-31. Spec for the next implementation cycle.
> **Repos touched:** `heartbeat-server` (Go relay) and `heart-beat-v3` (Flutter client).
> **Central principle this work serves:** *Reliability — every message is sent, every record is kept.* Presence is not just a badge; it is the trigger that closes the "couldn't deliver" gap.

---

## 1. Goal

Three deliverables, in this order:

1. **Server presence** — the relay tracks `last_seen` per pubkey and answers a batch presence query.
2. **Client green-tick + reliability** — a 3-state liveness badge next to every contact name, a foreground presence poller, and a **stale→online outbox flush** so undelivered messages go out the instant a peer becomes reachable. Plus a **records-integrity self-check** that surfaces any message that was sent but never confirmed delivered.
3. **3-emulator reliability campaign** — a comprehensive edge-case test plan run on three Android emulators, with every finding logged (no fixes this session).

This sequence was chosen deliberately: build the reliability feature first, then stress the whole system (including the new feature) end-to-end.

---

## 2. Scope

### In scope
- `heartbeat-server`: `last_seen` tracking in the hub + persisted to the phonebook DB; a new signed `POST /v1/presence` endpoint; tests; version bump; redeploy to GCP.
- `heart-beat-v3`: `PresenceClient`, presence state provider + foreground poller, 3-state badge on 4 UI surfaces, `OutboxRetransmitter.flushForPeer`, presence-triggered flush, records-integrity check + a diagnostics surface.
- Test plan + 3-emulator campaign + results doc.

### Out of scope (this cycle)
- Signal-style identity/safety-number verification (a *different* "verified" concept; not what the green tick means here).
- Presence privacy controls (hide last-seen). Noted as a follow-up.
- WS-push presence (we use HTTP poll). Noted as a follow-up.
- Group-member presence aggregation in group tiles (1:1 + contact rows only this cycle).
- Fixing bugs the campaign surfaces — those are **logged only** per decision.

---

## 3. Architecture

```
┌─────────────┐   POST /v1/presence (signed)        ┌──────────────────────┐
│ Flutter      │  {pubkeys:[...]}                    │ Go relay              │
│ client       │ ───────────────────────────────►   │                       │
│              │                                      │  Hub.conns (online)  │
│ PresencePoller│ ◄───────────────────────────────  │  Hub.lastSeen + DB   │
│ (fg, ~25s)   │   {pk:{online,last_seen}}           │  phonebook.last_seen │
└─────┬───────┘                                       └──────────────────────┘
      │ stale→online transition
      ▼
  OutboxRetransmitter.flushForPeer(pk)  ──►  pending rows nextRetryAt=now ──► sweep ──► resend
```

- **"Online now"** is read straight from the existing in-memory `Hub.conns` — zero new state, already authoritative.
- **`last_seen`** is updated on every WS connect/disconnect, kept both in-memory (fast) and in the phonebook table (durable across relay restarts).
- The client treats presence as **ephemeral UI state** (a provider keyed by pubkey), never persisted to drift.

---

## 4. Server changes (`heartbeat-server`)

### 4.1 `last_seen` in the hub
`internal/signaling/hub.go` — add to `Hub`:
```go
type Hub struct {
    mu       sync.RWMutex
    conns    map[string]Connection
    lastSeen map[string]time.Time // pubkey → last connect-or-disconnect time
}
```
- `Add(pubkey, c)` and `Remove(pubkey, c)` both set `lastSeen[pubkey] = time.Now()`.
- New `Snapshot(pubkeys []string) map[string]PresenceInfo` returns, per requested pubkey: `online = (conns[pk] != nil)`, `lastSeen = lastSeen[pk]` (falling back to the DB value when absent in memory, e.g. after a relay restart).

### 4.2 Persist `last_seen` to the phonebook DB
`internal/phonebook/store.go`:
- Schema: add `last_seen INTEGER NOT NULL DEFAULT 0` to the `phonebook` table. Because `CREATE TABLE IF NOT EXISTS` won't alter an existing table, add an idempotent `ALTER TABLE phonebook ADD COLUMN last_seen INTEGER NOT NULL DEFAULT 0` guarded by a "does column exist" check (PRAGMA table_info), matching the project's additive-migration style.
- New `TouchLastSeen(ctx, pubkey, ts)` (upsert-style update) and `LastSeenFor(ctx, pubkeys) map[string]int64`.
- The hub gets an injected callback/interface so it can persist on connect/disconnect without importing the phonebook package directly (keep the dependency direction clean; mirror how `signaling.Handlers` already receives `book` + `offQ`).

### 4.3 `POST /v1/presence` endpoint
New package `internal/presence` mirroring `internal/wake`:
- `Handlers{ Hub *signaling.Hub }` (the hub already has DB-backed fallback via 4.2).
- Request: `{"pubkeys":["<64hex>", ...]}` (cap at, say, 256 entries; reject longer with 400).
- Response: `{"presence":{"<pubkey>":{"online":true,"last_seen":1717160000}}}` (last_seen in Unix seconds; `0` = never seen).
- Signed via `auth.RequireSignature` (matches every other `/v1/*` route). The authenticated caller's own pubkey is ignored for the query result (any signed client may ask about any pubkey — consistent with the existing trust model where pubkeys are already shared to pair).
- Registered in `cmd/heartbeat-server/main.go` next to `/v1/wake`.
- Logging: `[presence] query pub=<shortPub> n=<count>`.

### 4.4 Tests + deploy
- `internal/presence/handlers_test.go` (mirror `phonebook/handlers_test.go`: `newAuthedRequest`, in-memory DB, `httptest`). Cover: online peer, offline-but-seen peer, never-seen peer, unsigned request rejected, oversized list rejected.
- `internal/signaling/hub_test.go`: `lastSeen` set on Add/Remove; `Snapshot` correctness.
- Bump `version` in `main.go` (e.g. `0.3.0-presence`). Redeploy via the distroless `scp` path from the `heartbeat-server-deploy` skill (the e2-micro OOMs on full `docker build`). Verify `/healthz` after.

---

## 5. Client changes (`heart-beat-v3`)

### 5.1 `PresenceClient` — `lib/services/presence_client.dart`
Mirror `phonebook_client.dart` exactly:
- POST to `baseUri.resolve('/v1/presence')`, body `{"pubkeys":[...]}`.
- Sign `'$rfc3339Ts\n$body'` with `SigningService`; set `X-Heartbeat-Pubkey/Sig/Timestamp`.
- Parse into `Map<String, PresenceInfo>` where `PresenceInfo { bool online; DateTime? lastSeen; }` (lastSeen null when `last_seen == 0`).
- Injectable `http.Client` for tests; structured result enum for network/server errors (mirror `PhonebookRegisterResult`).
- Base URL: reuse `relayHttpBaseUrl` from `lib/features/notifications/fcm_provider.dart`.

### 5.2 Presence state + poller — `lib/features/presence/presence_provider.dart`
- `PresenceState` = `Map<String /*pubkeyHex*/, PresenceInfo>` exposed via a `Notifier`/`StateNotifier`.
- `PresenceStatus` derived enum: `online | recent | stale` (see §6 for thresholds).
- **Poller:** runs only while `AppLifecycleState.resumed`. On a `~25s` timer (and once immediately on foreground), it:
  1. Reads the contact list (`contactsListProvider`).
  2. Calls `presenceClient.fetchPresence(pubkeys)`.
  3. Diffs against prior state; for any pubkey transitioning **stale/recent/offline → online**, calls the flush hook (§5.4).
  4. Updates the provider (UI repaints).
- Lifecycle wiring lives in `main.dart` alongside the existing `didChangeAppLifecycleState` block: start/stop the poller on resume/pause. The poller is **paused in background** (no battery/data drain, no value while you can't see the UI).
- Network failures are swallowed (presence is best-effort; a failed poll just leaves the last-known state and is retried next tick).

### 5.3 Green-tick badge — UI
A small reusable `PresenceBadge(pubkeyHex)` `ConsumerWidget` that reads the presence provider and renders a 9–10px dot:
- placed next to the resolved name on: `chat_list_screen.dart` direct tiles (`_buildDirectTile`, ~line 290), `contacts_screen.dart` (~line 50), `select_contact_screen.dart` (~line 94), and `chat_thread_screen.dart` header (~line 144, plus a "online / last seen …m ago" subtitle line).
- Group tiles get **no** badge this cycle.
- Colors: online = `AppColors.green`; recent = a softened/amber tone; stale = `onSurface.withValues(alpha: 0.35)` hollow ring. (Keeps the existing dimmed-text convention.)

### 5.4 Reliability: presence-triggered outbox flush
`lib/chat/outbox_retransmitter.dart` — add:
```dart
Future<int> flushForPeer(String peerPubkeyHex) async {
  // set nextRetryAt = now for all pending rows to this peer, then sweepOnce
}
```
- Implemented via a new `OutboxDao.kickPeer(peerPubkeyHex, DateTime now)` that updates `nextRetryAt = now` for matching non-failed rows (mirrors `bumpAttempt`/`markPeerFailed` style).
- The presence poller calls `messageService.flushPeerOnReachable(pk)` on a stale/offline→online transition, which delegates to `flushForPeer` then triggers an immediate sweep.
- Net effect: messages stranded by an earlier offline/wake-failure are resent the moment the peer is observed reachable — **the reliability core of this feature.**

### 5.5 Records-integrity self-check — `lib/features/diagnostics/`
A read-only audit that serves *"every record is kept"*:
- **`IntegrityReport`** computed on demand: scans for
  - outbox rows past `maxAge` (24h) still pending → **stuck** (would-be-lost messages),
  - messages marked `sent` by us with no delivery receipt and no live outbox row → **orphaned** (sent but unconfirmed),
  - chats referenced by messages but missing a `chats` row, and vice-versa → **dangling**.
- **Diagnostics screen** (reachable from My Profile → "Diagnostics", low-key): shows counts per category + a "Re-kick stuck outbox" action that calls `flushForPeer` for each stuck peer. No automatic mutation — surfacing only, plus an explicit user-triggered re-kick.
- This is intentionally lightweight: queries over existing tables, no schema change.

---

## 6. Green-tick semantics (3-state)

Presence = **reachability**, not identity verification.

| State | Condition | Visual |
|---|---|---|
| **online** | server reports `online == true` | solid green dot (`AppColors.green`) |
| **recent** | not online, but `last_seen` within **24h** | softened/amber dot |
| **stale** | not online and `last_seen` > 24h ago, or never seen | hollow grey ring |

- Threshold (`recent` window = 24h) is a single constant, easily tuned.
- Chat-thread header additionally shows text: `online` / `last seen 7m ago` / `last seen 3d ago` / `last seen never`.

---

## 7. Error handling & edge cases

- **Presence poll fails (network):** keep last-known state; retry next tick. Never blocks UI.
- **Relay restarted:** in-memory `lastSeen`/`conns` reset → everyone shows offline until they reconnect; `last_seen` from DB still gives a "last seen" time, so badges degrade to `recent/stale` rather than lying "online". (Reason last_seen is persisted.)
- **Contact with no phonebook entry / never connected:** `last_seen = 0` → `stale`, "last seen never".
- **Flush idempotency:** `flushForPeer` only re-kicks rows; the existing sweep + receipt-dedup (`msgId`) prevents duplicate delivery. Repeated online transitions are safe.
- **Force-stop FCM quirk** (testing-only, from deploy skill): `adb am force-stop` suppresses FCM until manual relaunch — the campaign must use **swipe-from-recents** for "natural kill" scenarios and reserve force-stop for the explicit force-stop persistence test.

---

## 8. Testing strategy

### 8.1 Unit tests (written with the implementation, TDD)
- Server: presence handler (online/offline/never/unsigned/oversized), hub lastSeen + Snapshot.
- Client: `PresenceClient` (happy path verifies signature canonicalization, 4xx, network error); presence provider transition logic (offline→online fires flush exactly once); `OutboxDao.kickPeer` + `flushForPeer`; integrity report categorization.
- Keep the suite green (currently ~257 passing + 5 skipped). `flutter analyze` clean. `flutter build apk --debug` succeeds.

### 8.2 Three-emulator reliability campaign
Produced as a separate **`docs/2026-05-31-emulator-e2e-test-plan.md`** (the full case catalog) and a **results doc** graded by severity. Three emulators: `Heartbeat`, `Heartbeat2`, plus a new `Heartbeat3` AVD (all Google-Play images so FCM works).

Edge-case families (full enumeration in the test-plan doc):
- **Delivery state matrix:** sender × receiver in {foreground, backgrounded, swipe-killed, force-stopped, emulator-offline} — every cell asserts the message arrives + is persisted on both ends.
- **Presence:** badge shows online/recent/stale correctly; transitions repaint within one poll; stale→online **flushes** a previously-stranded message.
- **Outbox/reliability:** send while peer offline → peer returns → message delivered without manual resend; receipts/ticks correct; no duplicates.
- **Groups (3 members):** create, add, remove, leave, group text fan-out, **offline group member** receives on return.
- **Persistence:** force-stop + relaunch preserves all chats/messages/group state/presence-after-poll; clear-data + re-pair re-registers and resumes.
- **Records integrity:** after a deliberately-stranded send, the diagnostics check flags it, and the re-kick recovers it.
- **Adversarial:** emulator dropped mid-send; relay reconnection; rapid online/offline flapping doesn't double-send.

All findings **logged only**, severity-graded against "every message sent / every record kept." Critical findings become follow-up tasks.

---

## 9. Privacy note

`last_seen` is exposed to any paired (signed) client. For a 2–3 person trusted-contact app this matches the threat model (you already exchanged pubkeys to pair). A "hide last seen" toggle is a deliberate **follow-up**, not this cycle.

---

## 10. Rollout / compatibility

- **Server:** additive column + new endpoint → fully backward-compatible; existing clients ignore it. Deploy server **first**.
- **Client:** presence is best-effort; on an old server the poll 404s and badges stay `stale` (graceful). No drift schema bump required (presence is ephemeral; integrity check is read-only).
- **Versioning:** server `0.3.0-presence`; client a normal `pubspec` bump; tag per existing convention after the campaign.

---

## 11. Proposed follow-ups (not this cycle)
- WS-push presence for instant updates (scaffold `buildIsOnline` already exists).
- "Hide last seen" privacy toggle (per-user, server-enforced).
- Group-member presence aggregation in group tiles ("3 online").
- Server-side application-level delivery ack (the deeper fix the roadmap flags) — would let the integrity check assert delivery authoritatively rather than inferring from receipts.

---

## 12. Acceptance criteria

- [ ] Relay tracks `last_seen` (in-memory + persisted) and `POST /v1/presence` returns correct online/last_seen for online, offline-seen, and never-seen pubkeys; signed-only; tested; deployed; `/healthz` green.
- [ ] Client paints the correct 3-state badge on chat-list, contacts, select-contact, and chat-thread header, updating within one poll while foregrounded; poller stops in background.
- [ ] A message that fails to deliver while a peer is offline is delivered automatically (no manual resend) when the peer next appears online — verified on emulators.
- [ ] Records-integrity diagnostics flags a deliberately-stranded message and the re-kick recovers it.
- [ ] Unit suite green, `flutter analyze` clean, debug APK builds, server `go test ./...` green.
- [ ] `docs/2026-05-31-emulator-e2e-test-plan.md` written; campaign run on 3 emulators; results doc with severity-graded findings committed.
