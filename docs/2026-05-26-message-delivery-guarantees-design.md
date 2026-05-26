# Message Delivery Guarantees — Design

**Date:** 2026-05-26
**Status:** Draft (sections 1–3 user-approved; section 4 in progress)
**Authors:** Sahit + Claude
**Related:** `testing-session-results-2026-05-24.md` (Issue #1, Issue #2)

---

## 1. Problem statement

Today's relay is fire-and-forget. The server's only definition of "delivered"
is `Hub.DeliverTo` returning `true` — i.e. a TCP write to the recipient's WS
returned no error. There is no end-to-end acknowledgement anywhere in the
system. This produces three distinct silent-loss modes, all of which look
identical to the sender (happy local bubble, no error indication):

| Failure | Mechanism |
|---|---|
| **Issue #2 / Scenario G** (force-stop) | Android suppresses FCM data to a force-stopped app. Server's `[wake] fcm_ok` log lies — the payload was dropped by the OS. The envelope only ever existed inside that FCM payload; nothing on the server survives. When the recipient relaunches, the server has nothing to re-flush. |
| **Issue #1 / Scenario A1** (phantom drop) | Server's WS write returns nil at the OS level even when the peer's socket is half-dead (TCP RST hasn't fired yet). The 5s server ping eventually notices and removes the session, but the in-flight frame is already lost. Comment at `handlers.go:99-105` calls this out: *"True elimination of the race requires application-level message acks."* |
| **Sender WS dies mid-send** | `RelayClient.send` throws `StateError` cleanly for new sends, but any bytes already handed to the sink are in TCP-land and unrecoverable without an ack. |

A second, related gap: the sender has no UI signal distinguishing "I typed
this and it sits in my outbox" from "the recipient's device actually got it"
from "the recipient actually saw it."

## 2. Goals and non-goals

### Goals

1. **No silent message loss** in any of the failure modes above, given the
   recipient eventually reconnects within a bounded retention window.
2. **WhatsApp-style ticks** (`sent` → `delivered` → `read`) in the chat UI so
   senders have visibility into actual delivery state.
3. **Server stays ciphertext-only.** No new plaintext or metadata exposure
   beyond what the routing layer already sees today.
4. **Eventually consistent** for the case where sender and recipient are
   never online simultaneously.

### Non-goals

- **Group-chat receipts.** Direct chats only in this phase. Group fan-out
  for receipts (delivered to N/M, read by K/M) introduces a separate set of
  privacy and UI questions and is deferred.
- **Multi-device per pubkey.** Heartbeat is identity-per-device. Out of scope.
- **Bandwidth optimization beyond batching.** Receipt batching (one receipt
  envelope per N msgIds via a 250 ms debounce) is the only optimization in
  this phase.
- **Read-receipt opt-out toggle.** Always-on for the ~10-user scope.
  Revisitable if the user base ever broadens.

## 3. Scope decisions (captured from Q&A)

| Decision | Choice | Rationale |
|---|---|---|
| Server retention semantics | **Delete on push** (TCP write returned nil) | Server stays dumb; client-side ACK + retransmit covers the half-dead-WS race. |
| Server storage | **SQLite (`modernc.org/sqlite`) in a Docker volume** | Pure-Go (no CGO), survives container redeploys, right-sized for ~10 users. |
| Read receipts | **Always on (delivered + read)** | For a ~10-user intimate group, knowing "they saw it" is the most valuable tick. |
| Receipt batching | **Per-peer, 250 ms debounce, multiple `msgIds` per receipt** | Cuts ack chatter on chat-open and on burst inbound. |
| Receipt envelope kind | **`delivery_receipt`** (new) — first-class message, E2EE through the same pipe | Server cannot distinguish it from a text envelope. Receipts are themselves queued + retransmitted if the original sender is offline. |
| User scope | **~10 users** | Drives the simplicity bias throughout. |

## 4. Architecture — two independent layers

Each layer closes a distinct failure class. Either alone is insufficient.

```
┌─────────────────────┐                ┌─────────────────────┐
│   Sender (heart-    │                │   Recipient (heart- │
│   beat-v3 client)   │                │   beat-v3 client)   │
│                     │                │                     │
│  ┌──────────────┐   │                │   ┌──────────────┐  │
│  │  Outbox DB   │   │                │   │  Messages DB │  │
│  │ (unacked     │   │  E2EE          │   │ (msgId-keyed │  │
│  │  msgs)       │◀──┼────ACKs────────┼──▶│  dedup)      │  │
│  └──────────────┘   │                │   └──────────────┘  │
│        │            │                │          ▲          │
└────────┼────────────┘                └──────────┼──────────┘
         │                                        │
         │     ┌─────────────────────────────┐    │
         │     │   heartbeat-server (Go)     │    │
         │     │                             │    │
         └────▶│  Hub (live WS sessions)     │────┘
               │            │                │
               │            ▼                │
               │   [recipient offline?]      │
               │            │                │
               │            ▼                │
               │  ┌──────────────────────┐   │
               │  │ SQLite offline queue │   │
               │  │ pubkey → [ciphertext]│   │
               │  │ FIFO, capped         │   │
               │  └──────────────────────┘   │
               │            │                │
               │            ▼                │
               │   flush on WS reconnect     │
               │   delete on push success    │
               └─────────────────────────────┘
```

### 4a. Layer A — server offline queue

Closes the **recipient-offline** class (Scenario G, FCM-suppressed,
recipient process killed, etc.).

- On `DeliverTo` returning `false`, the server appends opaque ciphertext to
  a SQLite-backed per-recipient FIFO, then fires FCM (existing behavior).
- On the next WS connect for that pubkey, the server drains the queue into
  the fresh session, deleting each row the instant its push returns `nil`.
- Server never parses envelope contents. Rows are
  `(recipient_pubkey, sender_pubkey, ciphertext_bytes, enqueued_at)`.

### 4b. Layer B — client ACK + retransmit

Closes the **half-dead-WS** class (Issue #1) and provides UI tick state.

- Every outbound text carries a UUIDv4 `msgId` inside the inner E2EE envelope.
- Recipient sends a `delivery_receipt` envelope (new kind) back over the
  same E2EE pipe on decrypt-success (`delivered`) and on chat-view (`read`).
- Sender persists each outbound msg in an `outbox` table with state
  `sent | delivered | read`. UI ticks render from that column.
- A periodic sweep on the sender retransmits any `sent`-state outbox row
  older than 30s, with exponential backoff out to ~1h, then surfaces a
  "failed" tick after ~24h.

### 4c. Why both

| Scenario | Layer A alone | Layer B alone | Both |
|---|---|---|---|
| Both online | ✓ direct push | ✓ direct push | ✓ confirmed delivered |
| Recipient offline, FCM works | ✓ flushes on reconnect | ⚠ sender must be online when recipient reconnects | ✓ |
| Recipient force-stopped, FCM dropped (G) | ✓ flushes on next WS connect | ⚠ same as above | ✓ |
| Half-dead WS race (Issue #1) | ✗ server thinks pushed, deletes | ✓ sender retransmit catches it | ✓ |
| Sender offline before recipient comes back | ✓ recipient gets msg, ACK queued back via Layer A | ✗ stuck until sender returns | ✓ |
| Both offline | ✓ holds until either connects | ✗ | ✓ |

## 5. Wire protocol

Two changes, both inside the E2EE envelope. **Server frame shape is
unchanged** — server sees opaque ciphertext in both cases.

### 5a. `msgId` added to existing `text` inner envelope

```json
{
  "v": 1,
  "type": "text",
  "chatId": "<peer-pubkey or group-id>",
  "lamport": 42,
  "body": "hello",
  "senderDisplayName": "Sahit",
  "msgId": "550e8400-e29b-41d4-a716-446655440000"
}
```

`msgId` is the **single canonical identity** of the message everywhere:

- Sender's `outbox` table row PK.
- Sender's `messages` table row id (the existing UUID column — sender stops
  generating a separate one).
- Recipient dedup key. A duplicate inbound with the same `(sender, msgId)`
  pair is dropped silently. This matters because Layer A flush and Layer B
  retransmit can both legitimately deliver the same envelope in a race.
- Receipt target.

### 5b. New inner envelope kind: `delivery_receipt`

```json
{
  "v": 1,
  "type": "delivery_receipt",
  "chatId": "<peer-pubkey>",
  "lamport": 0,
  "msgIds": ["uuid-1", "uuid-2", "uuid-3"],
  "kind": "delivered" | "read",
  "at": "2026-05-26T15:30:45Z"
}
```

- `msgIds` is an **array** so chat-open with 20 unread msgs is one envelope.
  250 ms per-peer debounce on the recipient.
- `lamport: 0` — receipts are metadata, not user-visible messages; they do
  not advance the chat's lamport clock.
- Travels through `crypto.encrypt` → `EnvelopeWire.wrapMessage` → `relay.send`,
  identical pipeline to text. If the original sender is offline when a
  receipt arrives, the receipt itself gets queued by Layer A and flushed
  later. Receipts are first-class messages.
- A `read` receipt **implies** `delivered`. Sender state machine allows
  direct `sent → read` transition without an intervening `delivered`.

### 5c. Receipts in groups — out of scope this phase

Group chats continue to show only the "sent" tick (today's behavior). Adding
per-member receipt aggregation in groups is a separate design problem (UI for
N/M aggregation, privacy implications of one member's read state leaking to
all others) and is deferred.

### 5d. `InnerEnvelope.parse` gains a sixth branch

Today: dispatches on `type ∈ {text, group_invite, member_add, member_remove,
member_leave}`. Adds `delivery_receipt`. `MessageService._handleDeliver` gets
a matching `if (inner is DeliveryReceiptEnvelope) return
_handleDeliveryReceipt(frame, inner);` clause.

## 6. Server-side changes (heartbeat-server)

### 6a. New package: `internal/offline`

Single responsibility: opaque-bytes FIFO keyed by recipient pubkey. SQLite
via `modernc.org/sqlite`.

**Schema** (`/data/heartbeat-relay.db`):

```sql
CREATE TABLE IF NOT EXISTS offline_queue (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  recipient_pubkey TEXT    NOT NULL,
  sender_pubkey    TEXT    NOT NULL,  -- needed to rebuild DeliverFrame "from"
  envelope         BLOB    NOT NULL,
  enqueued_at      INTEGER NOT NULL   -- unix millis
);
CREATE INDEX IF NOT EXISTS idx_offline_recipient
  ON offline_queue(recipient_pubkey, enqueued_at);
```

`sender_pubkey` has to be persisted alongside the envelope because
`_handleDeliver` on the client uses `frame.fromPubkeyHex` to select the
libsignal session for decryption.

**Public API:**

```go
package offline

type Entry struct {
    ID       int64
    Sender   string  // pubkey hex
    Envelope []byte
}

type Queue interface {
    Enqueue(ctx context.Context, recipient, sender string, envelope []byte) error
    LoadFor(ctx context.Context, recipient string) ([]Entry, error) // read-only
    Delete(ctx context.Context, id int64) error
    Sweep(ctx context.Context, maxAge time.Duration) (int, error)
    Depth(ctx context.Context, recipient string) (int, error)
}
```

`LoadFor` is read-only; rows are deleted one-by-one **after** each successful
push so an abandoned flush doesn't lose un-pushed rows.

### 6b. Wire-in to `signaling/handlers.go`

Three edits, each minimal:

**i. Add field on `Handlers`:**

```go
type Handlers struct {
    Hub     *Hub
    Book    *phonebook.Store
    Sender  *wake.Sender
    Offline offline.Queue  // NEW — nil disables (tests / dev)
}
```

**ii. `handleFrame` "send" branch, `DeliverTo` false case:**

```go
if !h.Hub.DeliverTo(f.To, env, fromPub) {
    log.Printf("[ws] deliver_offline from=%s to=%s", shortPub(fromPub), shortPub(f.To))
    _ = sess.write(ctx, BuildErrorFrameForPeer("recipient_offline", f.To))
    h.wakeOfflineRecipient(ctx, fromPub, f.To, env)
    h.enqueueOffline(ctx, fromPub, f.To, env)   // NEW
}
```

`enqueueOffline` is best-effort — errors log but don't fail the send. We
never want the relay refusing a `send` because its disk is unhappy.

**iii. `Signal` handler, after `h.Hub.Add`:**

```go
h.Hub.Add(pubHex, sess)
log.Printf("[ws] connect pub=%s", shortPub(pubHex))
go h.flushOffline(ctx, sess, pubHex)   // NEW, async
```

### 6c. `flushOffline` semantics

```go
func (h *Handlers) flushOffline(ctx context.Context, sess *wsSession, pubHex string) {
    if h.Offline == nil { return }
    entries, err := h.Offline.LoadFor(ctx, pubHex)
    if err != nil { /* log + return */ }
    if len(entries) == 0 { return }
    log.Printf("[offline] flush_start pub=%s count=%d", shortPub(pubHex), len(entries))
    for _, e := range entries {
        if err := sess.Push(e.Envelope, e.Sender); err != nil {
            log.Printf("[offline] flush_abandon pub=%s err=%v", shortPub(pubHex), err)
            return  // session dead; rows remain for next connect
        }
        if err := h.Offline.Delete(ctx, e.ID); err != nil {
            log.Printf("[offline] delete_fail id=%d err=%v", e.ID, err)
            // push succeeded — continue. Recipient dedup by msgId handles dup risk.
        }
    }
    log.Printf("[offline] flush_done pub=%s", shortPub(pubHex))
}
```

**Two subtle properties:**

1. **Flush runs in its own goroutine, parallel to the WS read loop.** New
   messages can arrive from the recipient (e.g. ACKs heading back to original
   senders) interleaved with flush replays. Lamport ordering at the inner
   layer puts them back in order on display.
2. **Delete-after-push, not before.** If we deleted up-front, a mid-flush
   push failure would silently lose every remaining row. With delete-after-
   push and `return` on first failure, anything we didn't write is still
   queued for the next connect.

### 6d. Caps + retention

| Limit | Value | Why |
|---|---|---|
| Per-recipient row count | 500 | Hard cap; oldest evicted on insert when full. |
| Age | 7 days | Hourly sweep via `time.Ticker` in `main.go`. |
| Per-envelope size | 64 KiB | Defense-in-depth at Enqueue. |
| DB size warning | 100 MB | Log warning only; no enforcement. |

On cap-hit eviction, sender already received `recipient_offline` and queued
client-side, so Layer B retransmit will catch up when the recipient returns.

### 6e. `cmd/heartbeat-server/main.go` wiring

```go
q, err := offline.OpenSQLite("/data/heartbeat-relay.db")
if err != nil { log.Fatal(err) }
defer q.Close()

go offline.RunSweeper(ctx, q, 1*time.Hour, 7*24*time.Hour)

handlers := signaling.NewHandlers(hub, book, sender, q)
```

### 6f. Docker / persistence

`docker-compose.yml` gains one volume mount:

```yaml
services:
  heartbeat-relay:
    volumes:
      - heartbeat-relay-data:/data
volumes:
  heartbeat-relay-data:
```

Survives `docker compose down && up`, container redeploys, host reboots.
Backup = `tar` the volume.

### 6g. Observability

- `/healthz` gains `"offline_queue_total"` (sum of all rows).
- Structured logs on every queue op:
  `[offline] enqueued/evict_oldest/flush_start/flush_done/flush_abandon/delete_fail/sweep_deleted=N`.
- No new HTTP endpoint; `gcloud compute ssh ... docker logs heartbeat-relay
  | grep '\[offline\]'` is enough for ~10 users.

### 6h. Test surface

Integration tests in `internal/signaling`:

1. Enqueue-then-flush — A offline, B sends, A connects → A receives. Queue
   empty afterward.
2. Cap eviction — fill to 500 for offline recipient, #501 evicts #1.
3. Flush ordering — burst of 10 sends while offline, recipient connects →
   all 10 arrive in send order.

Unit tests for `offline.Queue` against `:memory:` SQLite.

### 6i. Migration / rollout

`CREATE TABLE IF NOT EXISTS` is idempotent on first server start. Clients
without Layer B still benefit fully from Layer A — server-side queue helps
every existing client transparently. No client-version gate.

## 7. Client-side changes (heart-beat-v3)

Heaviest layer of the design. Concentrated in the Drift DB layer,
`MessageService`, and the chat UI tick widget.

### 7a. Drift schema additions

Two changes, both additive — no destructive migration.

**i. `messages.delivery_state` column** (existing table):

```dart
enum DeliveryState { sent, delivered, read, failed }

class Messages extends Table {
  // ... existing columns ...
  IntColumn get deliveryState => intEnum<DeliveryState>()
      .withDefault(const Constant(0)); // sent
}
```

`sent` is the default because inbound messages never need this column
populated — there's no UI tick on inbound bubbles. Only outbound rows ever
transition beyond `sent`.

**ii. New `outbox` table:**

```dart
class Outbox extends Table {
  TextColumn get msgId => text()();              // UUID, PK
  TextColumn get peerPubkeyHex => text()();
  BlobColumn get envelopeBytes => blob()();      // pre-encrypted JSON inner envelope
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {msgId};
}
```

`envelopeBytes` stores the **inner JSON envelope plaintext**, not the
libsignal ciphertext. Reason: libsignal sessions advance state on every
encrypt — re-encrypting on retransmit produces a fresh ciphertext with the
correct ratchet state, where replaying a stored ciphertext could break the
session. The CPU cost of re-encrypt on each retry is negligible.

Migration: Drift schema version bump + `m.createTable(outbox)` +
`m.addColumn(messages, messages.deliveryState)` in `onUpgrade`.

### 7b. `InnerEnvelope` changes (`group_envelope.dart`)

- `TextEnvelope` gains a required `msgId` field.
- `InnerEnvelope.buildText` gains a required `msgId` parameter.
- New `DeliveryReceiptEnvelope` class:

  ```dart
  class DeliveryReceiptEnvelope implements InnerEnvelope {
    final String chatId;     // peer pubkey for direct chats
    final List<String> msgIds;
    final ReceiptKind kind;  // delivered | read
    final DateTime at;
    // senderDisplayName / lamport=0 inherited from base
  }
  ```

- `InnerEnvelope.buildDeliveryReceipt(...)` constructor.
- `InnerEnvelope.parse` dispatch table gains a `delivery_receipt` branch.

**Backwards-compat read path:** existing `TextEnvelope.parse` treats missing
`msgId` as a v0 message — fall back to generating one locally (no dedup
possible, but no loss). This lets new clients keep reading from old peers
during the rollout window.

### 7c. `MessageService.sendText` changes

```dart
Future<void> sendText({
  required String peerPubkeyHex,
  required String body,
}) async {
  await dao.ensureDirectChat(peerPubkeyHex);
  await _maybeSendOwnBundle(peerPubkeyHex);

  final msgId = _uuid.v4();                     // NEW
  final lamport = await dao.bumpLamport(peerPubkeyHex);
  final myName = await _currentDisplayName();

  final jsonBytes = InnerEnvelope.buildText(
    chatId: myPubkeyHex,
    lamport: lamport,
    body: body,
    senderDisplayName: myName,
    msgId: msgId,                                // NEW
  );

  await _persistOutbound(peerPubkeyHex, body, lamport, msgId);  // msgId is PK
  final now = DateTime.now();
  await outboxDao.insert(                       // NEW
    msgId: msgId,
    peerPubkeyHex: peerPubkeyHex,
    envelopeBytes: jsonBytes,
    createdAt: now,
    nextRetryAt: now.add(const Duration(seconds: 30)),  // first retry deadline
  );

  // ... rest unchanged: bundle gating, _encryptAndSend ...
}
```

**Key change in `_persistOutbound`:** the `messages.id` column now takes the
caller-supplied `msgId` instead of generating its own UUID. This collapses
two IDs into one — sender's `messages.id` matches the recipient's dedup key.

The outbox row is inserted **before** `_encryptAndSend`. If encrypt or send
throws, the row stays; the retransmitter picks it up. If send succeeds, the
row remains in implied-`sent` state until a `delivered` receipt arrives and
deletes it.

### 7d. Inbound text path — dedup + receipt enqueue

`_handleDeliver` for text envelopes gains two steps:

```dart
if (inner is TextEnvelope) {
  // NEW: dedup
  final existing = await dao.findMessageById(inner.msgId);
  if (existing != null && existing.senderPubkeyHex == frame.fromPubkeyHex) {
    _log('dedup_inbound msgId=${_short(inner.msgId)} '
         'from=${_short(frame.fromPubkeyHex)}');
    // Still enqueue a delivered receipt — the original might have been
    // lost, our previous receipt might not have reached the sender.
    receiptDebouncer.enqueueDelivered(
      peer: frame.fromPubkeyHex, msgId: inner.msgId);
    return;
  }

  // ... existing persist path with id: inner.msgId ...

  receiptDebouncer.enqueueDelivered(           // NEW
    peer: frame.fromPubkeyHex, msgId: inner.msgId);
}
```

Dedup key is `(senderPubkey, msgId)` because msgId uniqueness is only
guaranteed per-sender — different peers can independently generate the same
UUID (astronomically unlikely, but the type system shouldn't assume).

### 7e. Inbound receipt path — new

```dart
if (inner is DeliveryReceiptEnvelope) {
  for (final mid in inner.msgIds) {
    final outboxRow = await outboxDao.findByMsgId(mid);
    if (outboxRow == null) {
      // Receipt for a message we have no record of — older than retention,
      // or peer clock drift. Log + skip.
      _log('receipt_no_outbox msgId=${_short(mid)} '
           'from=${_short(frame.fromPubkeyHex)}');
      continue;
    }
    if (outboxRow.peerPubkeyHex != frame.fromPubkeyHex) {
      // Forged receipt — someone other than the recipient is acking. Drop.
      _log('receipt_peer_mismatch msgId=${_short(mid)}');
      continue;
    }
    final newState = inner.kind == ReceiptKind.read
        ? DeliveryState.read
        : DeliveryState.delivered;
    // Monotonic state machine: never downgrade. A `delivered` receipt that
    // arrives after a `read` receipt (legal — receipts are best-effort and
    // can reorder under retry+queue) must not flip the tick back.
    await dao.advanceDeliveryStateIfHigher(mid, newState);
    await outboxDao.delete(mid);  // either state implies receipt arrived
  }
  return;
}
```

`advanceDeliveryStateIfHigher` is a new DAO method that updates only when
the new state's ordinal is strictly greater than the current
(`sent < delivered < read`; `failed` is a terminal side-state that
shouldn't be reached if a receipt is arriving).

**Spoof guard:** receipts only count when they come from the peer we
originally sent to. Without this, anyone who can route messages to us could
forge a "delivered" tick.

### 7f. New `DeliveryReceiptDebouncer`

Per-peer accumulator that batches msgIds within a 250 ms window:

```dart
class DeliveryReceiptDebouncer {
  final MessageService _svc;
  final Map<String, _PendingBatch> _byPeer = {};

  void enqueueDelivered({required String peer, required String msgId}) {
    final batch = _byPeer.putIfAbsent(peer,
        () => _PendingBatch(kind: ReceiptKind.delivered));
    batch.msgIds.add(msgId);
    batch.timer ??= Timer(const Duration(milliseconds: 250),
        () => _flush(peer));
  }

  void enqueueRead({required String peer, required List<String> msgIds}) {
    // Read receipts are emitted on chat-view in bulk; no debounce needed.
    _flushImmediate(peer, msgIds, ReceiptKind.read);
  }

  Future<void> _flush(String peer) async {
    final batch = _byPeer.remove(peer);
    if (batch == null || batch.msgIds.isEmpty) return;
    batch.timer?.cancel();
    final envBytes = InnerEnvelope.buildDeliveryReceipt(
      chatId: peer, msgIds: batch.msgIds.toList(),
      kind: batch.kind, at: DateTime.now(),
      senderDisplayName: await _svc._currentDisplayName(),
    );
    try {
      await _svc._encryptAndSend(peer, envBytes);
    } catch (e, st) {
      _log('receipt_send_fail peer=${_short(peer)} err=$e\n$st');
      // Best-effort. If receipt fails, sender's retransmitter eventually
      // retries the original message; we'll send a fresh receipt then.
    }
  }
}
```

`enqueueRead` flushes immediately because reads are batched at the source:
when a chat thread becomes visible, the UI collects all unread msgIds in
that thread and calls `enqueueRead` once with the full list.

### 7g. New `OutboxRetransmitter`

```dart
class OutboxRetransmitter {
  final MessageService _svc;
  Timer? _sweepTimer;

  void start() {
    _sweepTimer ??= Timer.periodic(
        const Duration(seconds: 10), (_) => _sweep());
  }

  Future<void> _sweep() async {
    final now = DateTime.now();
    final due = await _svc.outboxDao.dueBefore(now);
    for (final row in due) {
      try {
        await _svc._encryptAndSend(row.peerPubkeyHex, row.envelopeBytes);
        _log('retransmit msgId=${_short(row.msgId)} attempt=${row.attempt + 1}');
      } catch (e) {
        _log('retransmit_fail msgId=${_short(row.msgId)} err=$e');
      }
      await _svc.outboxDao.bumpAttempt(row.msgId, _nextRetry(row.attempt + 1));
      if (row.attempt + 1 >= _maxAttempts || _isExpired(row)) {
        await _svc.dao.updateDeliveryState(row.msgId, DeliveryState.failed);
        await _svc.outboxDao.delete(row.msgId);
      }
    }
  }

  Duration _nextRetry(int attempt) {
    // 30s → 1m → 5m → 30m → 1h → 1h → ... capped.
    const ladder = [30, 60, 300, 1800, 3600];
    final secs = attempt < ladder.length
        ? ladder[attempt]
        : ladder.last;
    return Duration(seconds: secs);
  }

  static const _maxAttempts = 24; // ~24h with the ladder above
  bool _isExpired(OutboxRow row) =>
      DateTime.now().difference(row.createdAt) > const Duration(hours: 24);
}
```

**Initial `nextRetryAt`** is set to `createdAt + 30s` on insert, so a freshly
sent message gets its first retransmit attempt 30s after creation — enough
breathing room for the normal happy-path delivered ack to arrive first.

On WS reconnect, the retransmitter doesn't need a special hook — the 10s
sweep picks everything up. A `kickSweep()` on `relay.onConnected` is a
nice-to-have for faster convergence; minor optimization.

### 7h. Chat UI — tick rendering

`MessageBubble` reads `messages.deliveryState` and renders:

| State | Icon |
|---|---|
| `sent` | single check |
| `delivered` | double check, muted color |
| `read` | double check, accent color |
| `failed` | exclamation, tap-to-retry |

Only renders on outbound messages (`senderPubkeyHex == myPubkeyHex`).
Inbound bubbles never show a tick.

**Tap-to-retry on `failed`** resets the row's `delivery_state` to `sent` and
re-inserts an outbox row (with `attempt=0`, `nextRetryAt=now`) so the
retransmitter picks it up on its next sweep.

### 7i. Read-receipt trigger

When a chat thread becomes visible (`ChatScreen` foreground + scroll
position shows the latest msg):

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) _markReadIfFocused();
}

Future<void> _markReadIfFocused() async {
  final unreadMsgIds = await dao.unreadInboundMsgIds(peerPubkeyHex);
  if (unreadMsgIds.isEmpty) return;
  await dao.markRead(unreadMsgIds);          // local DB only
  messageService.receiptDebouncer.enqueueRead(
      peer: peerPubkeyHex, msgIds: unreadMsgIds);
}
```

`unreadInboundMsgIds` is a new DAO query: `messages` rows where
`senderPubkeyHex == peer` AND no local viewed-at timestamp.

### 7j. New `outbox_dao.dart`

Standard Drift DAO with `insert`, `findByMsgId`, `dueBefore(DateTime)`,
`bumpAttempt(msgId, nextRetryAt)`, `delete(msgId)`, `markPeerFailed(peer)`.
Mirrors the style of `peer_bundle_state_dao.dart`.

### 7k. Lifecycle wiring (`message_service_provider.dart`)

```dart
final svc = MessageService(...);
svc.receiptDebouncer = DeliveryReceiptDebouncer(svc);
svc.retransmitter = OutboxRetransmitter(svc)..start();
ref.onDispose(() => svc.retransmitter.stop());
```

### 7l. What stays the same

- libsignal session lifecycle, X3DH bootstrap, bundle exchange.
- Group fan-out (`sendGroupText` etc.). Groups don't get receipts this
  phase. Group text messages still get a `msgId` (it doesn't hurt), but the
  inbound dedup just no-ops the existing-row check on groups because there's
  no per-member receipt path consuming msgIds yet.
- FCM wake client. Still fires on `recipient_offline`. Server-side queue +
  client retransmit are additive.

### 7m. Removals

- `_unackedByPeer` in-memory map at `message_service.dart:79`. Its job
  (deciding when to fire client-side wake) was always a heuristic. With the
  server-side queue doing the heavy lifting and the outbox driving
  retransmit, the map is redundant. Fire the client-side wake on every
  `recipient_offline` unconditionally — it's idempotent server-side.

### 7n. Test surface

- `outbox_dao_test.dart` — CRUD + `dueBefore` ordering.
- `message_service_test.dart` extensions:
  - `sendText` writes outbox row + messages row with same msgId.
  - Inbound text with known msgId → dedup'd, single receipt enqueued.
  - Inbound `delivery_receipt` → outbox row deleted, messages.deliveryState
    advances.
  - Forged receipt (wrong peer) → ignored.
  - Retransmitter sweep advances state on send success.
- `receipt_debouncer_test.dart` — 250 ms batch, multi-peer isolation.

### 7o. UX edge cases worth noting

- **Receipt arrives before the message is persisted** (sender's retransmit
  fires, recipient was already processing the first copy). With the dedup
  branch at 7d emitting a receipt even on duplicate inbound, the sender
  receives the receipt either way. No special handling.
- **User deletes a contact, then re-pairs.** Old outbox rows for that peer
  reference a libsignal session that no longer exists. The retransmitter's
  `_encryptAndSend` will throw on encrypt; mark those rows `failed` rather
  than retrying forever. The existing `forgetPeer` hook (already called
  from `deleteContact` as of v1.0.3) gains a sibling call:
  `outboxDao.markPeerFailed(peerPubkey)`.
- **Outbox row for a peer who never came back.** The 24h expiry catches it
  — the row transitions to `failed` and tap-to-retry surfaces in the UI.

## 8. Open questions

- Should we expose a debug screen showing outbox depth + retry state for
  diagnostics (like the Phase 10.3 wake-state debug screen)? Not required
  for the spec; can be added later if real-world debugging needs it.

## 9. Non-changes (calling out what stays identical)

- Hub session tracking + 5 s ping loop.
- FCM wake path (`wakeOfflineRecipient`) — still fires alongside the new
  queue write. Belt-and-suspenders: FCM still wakes recipients whose OS
  isn't suppressing it; queue catches the rest.
- Pre-key bundle delivery path. Bundles get queued just like message
  envelopes — server doesn't distinguish — and the recipient's existing
  `processPeerPreKeyBundle` is already idempotent, so a duplicate from a
  Layer A flush + Layer B retry is harmless.
- libsignal session lifecycle. `msgId` lives inside the inner envelope and
  is invisible to the libsignal layer.
- All authentication / signature surfaces.

## 10. Rollout

- Phase 1: ship server-side queue (Layer A) alone. Existing clients benefit
  immediately for the offline-recipient case. No client version gate.
- Phase 2: ship client `msgId` + outbox + receipts (Layer B). Backward-
  compatible: an old client receiving a `delivery_receipt` envelope drops it
  in the `unhandled_inner_type` branch (already exists at
  `message_service.dart:831`); a new client receiving a text envelope without
  `msgId` falls back to local UUID generation (no dedup possible across
  resends to that peer, but no message loss).
