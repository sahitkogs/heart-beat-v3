# Phase 2 — Client Receipts + Outbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-message `msgId` + outbox + `delivery_receipt` envelope + WhatsApp-style sent/delivered/read tick UI to the heart-beat-v3 Flutter client, closing the half-dead-WS race (Issue #1) and giving the sender real delivery visibility on top of the server-side queue shipped in 10.4.3a.

**Architecture:** Two new domain classes (`DeliveryReceiptDebouncer`, `OutboxRetransmitter`) wired into the existing `MessageService`. Two Drift schema additions (`messages.delivery_state` column + new `outbox` table) via an additive v6 → v7 migration. One new inner envelope kind (`delivery_receipt`). Sender persists outbound msgs to `outbox` keyed by `msgId` (now also `messages.id`), recipient sends `delivery_receipt` envelopes through the same E2EE pipe, sender's `outbox` row deletes when its receipt arrives — drives `delivery_state` ∈ {sent, delivered, read, failed} which the chat UI renders as ticks. Periodic retransmitter sweeps `sent`-state outbox rows older than their `nextRetryAt` with an exponential ladder out to ~24h.

**Tech Stack:** Dart 3 / Flutter, Drift (SQLite), libsignal_protocol_dart, riverpod. No new external dependencies (uuid is already in pubspec.lock via `uuid: 4.x`).

**Spec:** `heart-beat-v3/docs/2026-05-26-message-delivery-guarantees-design.md` §5 (wire), §7 (client changes), §9 (non-changes), §10 (rollout). This plan implements Phase 2 of §10.

**Prerequisite:** Phase 10.4.3a (server-side offline queue) shipped to prod 2026-05-26 as `heartbeat-server v0.2.0-offline-queue`. This plan assumes the live relay at `34.42.231.29:8080` exposes `offline_queue_total` in `/healthz` and persists undelivered envelopes per-recipient.

---

## File Structure

**New files:**

| File | Responsibility |
|---|---|
| `lib/data/outbox_dao.dart` | Drift DAO for the `outbox` table — `insert`, `findByMsgId`, `dueBefore(DateTime)`, `bumpAttempt`, `delete`, `markPeerFailed`. Mirrors `peer_bundle_state_dao.dart`. |
| `lib/chat/delivery_receipt_debouncer.dart` | Per-peer accumulator of msgIds with a 250 ms debounce for `delivered`, immediate flush for `read`. Calls `MessageService._encryptAndSend` to ship the receipt envelope. |
| `lib/chat/outbox_retransmitter.dart` | 10-second periodic timer; reads `outboxDao.dueBefore(now)`, retransmits each row, bumps `attempt + nextRetryAt` per the ladder (30s / 1m / 5m / 30m / 1h / 1h…), marks `failed` after 24h. |
| `test/data/outbox_dao_test.dart` | CRUD + ordering + `dueBefore` window. |
| `test/data/migration_v6_to_v7_test.dart` | Migration stub (skipped, live-verified) per repo precedent. |
| `test/chat/delivery_receipt_debouncer_test.dart` | 250 ms batch, multi-peer isolation, immediate-read path. |
| `test/chat/outbox_retransmitter_test.dart` | Sweep advances state, ladder picks correct next interval, 24h expiry marks failed. |

**Modified files:**

| File | Change |
|---|---|
| `lib/data/app_database.dart` | New `Outbox` table; `DeliveryState` enum; `Messages.deliveryState` column; `schemaVersion` bumps 6 → 7; `onUpgrade` gains `v == 6` branch (`addColumn` + `createTable`). |
| `lib/data/chats_dao.dart` | New methods: `advanceDeliveryStateIfHigher`, `findMessageById`, `unreadInboundMsgIds`, `markRead`, `watchDeliveryState`. |
| `lib/chat/chat_providers.dart` | New `outboxDaoProvider`. |
| `lib/chat/group_envelope.dart` | `TextEnvelope.msgId` required field; `buildText` gains required `msgId` param; parse fallback (generate UUID when missing — backwards-compat for pre-Phase-2 peers). New `DeliveryReceiptEnvelope` + `ReceiptKind` enum + `buildDeliveryReceipt` + parse branch. |
| `lib/chat/message_service.dart` | `sendText` writes outbox row + uses msgId in inner envelope and `messages.id`. `_handleDeliver` text branch gains dedup-by-(sender, msgId) + receipt enqueue. New `_handleDeliveryReceipt` branch. Drop `_unackedByPeer` map; `_handleError` fires wake unconditionally. Add `outboxDao` field. Late-init `receiptDebouncer` + `retransmitter`. `forgetPeer` cascades `outboxDao.markPeerFailed`. |
| `lib/features/chat/message_service_provider.dart` | Construct + assign debouncer + retransmitter after MessageService is created; pass `outboxDao` through constructor; stop retransmitter on dispose. |
| `lib/features/chat/message_bubble.dart` | New required `deliveryState` + optional `onRetryTap` params. Render ticks for outbound bubbles per state. |
| `lib/features/chat/chat_thread_screen.dart` | On `didChangeAppLifecycleState(resumed)` + on initial build, mark unread inbound msgs read and call `receiptDebouncer.enqueueRead`. Pass `deliveryState` + retry callback to each `MessageBubble`. |
| `lib/features/chat/chat_thread_provider.dart` (if separate) | Watch `messages.deliveryState` so bubbles re-render when receipts land. |
| `test/chat/message_service_test.dart` | Extensions for sendText-writes-outbox, dedup, receipt advances state, receipt spoof guard, retransmit sweep. |

**No changes:**

- `heartbeat-server` — Layer A already handles ciphertext routing for receipts identically to text envelopes (server sees opaque bytes).
- `libsignal_crypto_service.dart` — receipts go through `crypto.encrypt`/`crypto.decrypt` identically to text. The msgId lives inside the post-decrypt JSON.
- `relay_client.dart`, `relay_frames.dart` — wire is unchanged.
- `services/wake_client.dart`, `services/fcm_service.dart`, `services/background_message_handler.dart` — wake fallback path is unchanged; only the trigger condition simplifies.

---

## Cross-cutting conventions

- **TDD throughout** — every code task starts with a failing test.
- **Quality gates per task:** `flutter test` green, `flutter analyze` no new warnings, `flutter build apk --debug` green at the final integration task. Run all three before any commit that touches `lib/`.
- **One commit per task**, message format `"<area>: <terse>"` mirroring 10.4.2/10.4.3a style (e.g. `outbox: dao with dueBefore + markPeerFailed`).
- **Linear history on `main`**, no force-push.
- **Drift codegen** — `flutter pub run build_runner build --delete-conflicting-outputs` after any change to a `@DriftAccessor` class or to `Tables` in `app_database.dart`. Run before each test that depends on the generated `.g.dart`.
- **Run commands from** `C:/Users/Lambda/Documents/heart-beat-v3/`. PowerShell-style paths used below; Bash equivalents are interchangeable since `flutter` is in PATH.

---

## Task 1: Drift schema bump — `DeliveryState` enum + `Outbox` table + `messages.delivery_state` column

**Files:**
- Modify: `lib/data/app_database.dart`
- Create: `test/data/migration_v6_to_v7_test.dart`

- [ ] **Step 1: Write the migration stub test**

Create `test/data/migration_v6_to_v7_test.dart`:

```dart
// Migration test stub. Live-verified on-device during F1 of the 10.4.3b
// quality-gate run (fresh APK install over a v6 install on a real device).
// Offline drift schema-snapshot infra is intentionally not wired up — same
// rationale as the 10.4 T2.2 / v5 -> v6 migration test decisions.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v6 -> v7 adds delivery_state column + outbox table', () {
    // Intentionally empty — verified on-device during 10.4.3b F1.
  }, skip: 'live-verified on device upgrade — see plan Task 17');
}
```

- [ ] **Step 2: Run to confirm test infra works**

```powershell
cd C:/Users/Lambda/Documents/heart-beat-v3
flutter test test/data/migration_v6_to_v7_test.dart
```

Expected: 0 passed, 1 skipped.

- [ ] **Step 3: Add the enum + column + table to `app_database.dart`**

In `lib/data/app_database.dart`, just below the existing `class Messages extends Table { ... }` block, add:

```dart
/// Per-outbound-message delivery progress. Default is `sent` (the row was
/// persisted by the sender); receipts advance the state monotonically.
/// Inbound rows never read this column — only outbound bubbles render a tick.
enum DeliveryState { sent, delivered, read, failed }
```

Inside `class Messages extends Table { ... }`, add a new column right after `kind`:

```dart
IntColumn get deliveryState =>
    intEnum<DeliveryState>().withDefault(const Constant(0))(); // sent
```

After the `class PeerBundleState extends Table { ... }` block, add the new `Outbox` table:

```dart
/// Unacked outbound messages. Row inserted by `MessageService.sendText`
/// before `_encryptAndSend`. Row deleted when a `delivery_receipt` envelope
/// arrives for `msgId`. Periodic retransmitter sweeps rows whose
/// `nextRetryAt` is in the past. `attempt` drives the backoff ladder.
class Outbox extends Table {
  TextColumn get msgId => text()();                    // UUIDv4, also messages.id
  TextColumn get peerPubkeyHex => text()();
  BlobColumn get envelopeBytes => blob()();            // pre-encrypted JSON inner envelope
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {msgId};
}
```

Add `Outbox` to the `@DriftDatabase(tables: [...])` list (alphabetized after `LamportSeq` is fine; the exact slot doesn't matter, but place it near the other application tables for readability — recommended: after `PeerBundleState`).

Bump `schemaVersion`:

```dart
@override
int get schemaVersion => 7;
```

Extend `onUpgrade` with the new branch (immediately after the existing `else if (v == 5)` block):

```dart
} else if (v == 6) {
  // 10.4.3b — additive: outbox table + messages.delivery_state column.
  // No data is dropped; existing messages keep delivery_state == 0 (sent).
  await m.createTable(outbox);
  await m.addColumn(messages, messages.deliveryState);
}
```

- [ ] **Step 4: Regenerate Drift code**

```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: regenerates `app_database.g.dart` cleanly (will report ~1 new table, ~1 new column).

- [ ] **Step 5: Run full test suite to confirm schema change doesn't break existing tests**

```powershell
flutter test
```

Expected: all existing tests still pass. The new migration test is skipped.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/app_database.dart lib/data/app_database.g.dart `
        test/data/migration_v6_to_v7_test.dart
git commit -m "data: schema v6->v7 — outbox table + messages.delivery_state"
```

---

## Task 2: `OutboxDao` — CRUD + `dueBefore` + `markPeerFailed`

**Files:**
- Create: `lib/data/outbox_dao.dart`
- Create: `test/data/outbox_dao_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/outbox_dao_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/outbox_dao.dart';

void main() {
  late AppDatabase db;
  late OutboxDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = OutboxDao(db);
  });

  tearDown(() async => db.close());

  test('insert + findByMsgId round-trip', () async {
    final now = DateTime.now();
    await dao.insert(
      msgId: 'm1', peerPubkeyHex: 'peerA',
      envelopeBytes: [1, 2, 3],
      createdAt: now, nextRetryAt: now.add(const Duration(seconds: 30)),
    );
    final row = await dao.findByMsgId('m1');
    expect(row, isNotNull);
    expect(row!.peerPubkeyHex, 'peerA');
    expect(row.envelopeBytes, [1, 2, 3]);
    expect(row.attempt, 0);
  });

  test('findByMsgId returns null for missing', () async {
    expect(await dao.findByMsgId('nope'), isNull);
  });

  test('dueBefore returns only rows past nextRetryAt, ordered by createdAt', () async {
    final t0 = DateTime(2026, 5, 26, 12, 0, 0);
    await dao.insert(msgId: 'a', peerPubkeyHex: 'p', envelopeBytes: [1],
        createdAt: t0, nextRetryAt: t0.add(const Duration(seconds: 10)));
    await dao.insert(msgId: 'b', peerPubkeyHex: 'p', envelopeBytes: [2],
        createdAt: t0.add(const Duration(seconds: 1)),
        nextRetryAt: t0.add(const Duration(seconds: 60)));
    await dao.insert(msgId: 'c', peerPubkeyHex: 'p', envelopeBytes: [3],
        createdAt: t0.add(const Duration(seconds: 2)),
        nextRetryAt: t0.add(const Duration(seconds: 5)));

    final due = await dao.dueBefore(t0.add(const Duration(seconds: 30)));
    expect(due.map((r) => r.msgId).toList(), ['a', 'c']); // ordered by createdAt
  });

  test('bumpAttempt updates attempt + nextRetryAt', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'm', peerPubkeyHex: 'p', envelopeBytes: [9],
        createdAt: now, nextRetryAt: now);
    final next = now.add(const Duration(minutes: 5));
    await dao.bumpAttempt('m', next);
    final row = await dao.findByMsgId('m');
    expect(row!.attempt, 1);
    expect(row.nextRetryAt, next);
  });

  test('delete removes the row', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'm', peerPubkeyHex: 'p', envelopeBytes: [1],
        createdAt: now, nextRetryAt: now);
    await dao.delete('m');
    expect(await dao.findByMsgId('m'), isNull);
  });

  test('markPeerFailed deletes only that peer\'s rows', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'p1m1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
        createdAt: now, nextRetryAt: now);
    await dao.insert(msgId: 'p1m2', peerPubkeyHex: 'peerA', envelopeBytes: [2],
        createdAt: now, nextRetryAt: now);
    await dao.insert(msgId: 'p2m1', peerPubkeyHex: 'peerB', envelopeBytes: [3],
        createdAt: now, nextRetryAt: now);

    final dropped = await dao.markPeerFailed('peerA');
    expect(dropped, 2);
    expect(await dao.findByMsgId('p1m1'), isNull);
    expect(await dao.findByMsgId('p1m2'), isNull);
    expect(await dao.findByMsgId('p2m1'), isNotNull);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/data/outbox_dao_test.dart
```

Expected: build error — `package:app_v3/data/outbox_dao.dart` does not exist.

- [ ] **Step 3: Implement the DAO**

Create `lib/data/outbox_dao.dart`:

```dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<void> insert({
    required String msgId,
    required String peerPubkeyHex,
    required List<int> envelopeBytes,
    required DateTime createdAt,
    required DateTime nextRetryAt,
  }) async {
    await into(outbox).insertOnConflictUpdate(
      OutboxCompanion.insert(
        msgId: msgId,
        peerPubkeyHex: peerPubkeyHex,
        envelopeBytes: envelopeBytes,
        createdAt: createdAt,
        nextRetryAt: nextRetryAt,
      ),
    );
  }

  Future<OutboxData?> findByMsgId(String msgId) =>
      (select(outbox)..where((t) => t.msgId.equals(msgId))).getSingleOrNull();

  /// Rows whose `nextRetryAt <= now`, oldest `createdAt` first. The
  /// retransmitter consumes this list per sweep.
  Future<List<OutboxData>> dueBefore(DateTime now) =>
      (select(outbox)
            ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> bumpAttempt(String msgId, DateTime nextRetryAt) async {
    await (update(outbox)..where((t) => t.msgId.equals(msgId))).write(
      OutboxCompanion(
        attempt: Value(
          (await findByMsgId(msgId))?.attempt != null
              ? (await findByMsgId(msgId))!.attempt + 1
              : 1,
        ),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  Future<void> delete(String msgId) async {
    await (this.delete(outbox)..where((t) => t.msgId.equals(msgId))).go();
  }

  /// Drops every outbox row for [peerPubkeyHex]. Returns the count. Called
  /// from `MessageService.forgetPeer` so a deleted+re-paired contact doesn't
  /// keep retransmitting against a libsignal session that no longer exists.
  Future<int> markPeerFailed(String peerPubkeyHex) async {
    return (this.delete(outbox)
          ..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .go();
  }
}
```

> **Note on `bumpAttempt`:** the double `findByMsgId` inside `Value(...)` is wasteful — the inner `if` runs twice. The cleaner shape is below; use this version when implementing (the test above doesn't care which way you compute the next attempt):
>
> ```dart
> Future<void> bumpAttempt(String msgId, DateTime nextRetryAt) async {
>   final existing = await findByMsgId(msgId);
>   final nextAttempt = (existing?.attempt ?? 0) + 1;
>   await (update(outbox)..where((t) => t.msgId.equals(msgId))).write(
>     OutboxCompanion(
>       attempt: Value(nextAttempt),
>       nextRetryAt: Value(nextRetryAt),
>     ),
>   );
> }
> ```

- [ ] **Step 4: Regenerate Drift code**

```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: creates `lib/data/outbox_dao.g.dart`.

- [ ] **Step 5: Run the tests**

```powershell
flutter test test/data/outbox_dao_test.dart
```

Expected: all 6 tests PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/outbox_dao.dart lib/data/outbox_dao.g.dart test/data/outbox_dao_test.dart
git commit -m "outbox: dao with dueBefore + markPeerFailed"
```

---

## Task 3: `ChatsDao` extensions for receipts + dedup + read-tracking

**Files:**
- Modify: `lib/data/chats_dao.dart`
- Modify: `test/data/chats_dao_test.dart` (or extend if structured per existing pattern)

These are the small queries `MessageService` and `ChatThreadScreen` need: look up a message by id (for dedup), advance delivery state monotonically (for receipts), watch a single message's state (for tick re-render), list unread inbound msgIds for a peer (for read receipts), and mark them locally read.

> **Read-tracking design note:** "Unread" is defined as `senderPubkeyHex == peer AND read_at IS NULL`. That requires a new `read_at` nullable DateTime on `messages`. We piggyback on this task rather than spinning a v7 → v8 migration: add the column inside the same v6 → v7 migration (edit Task 1's migration branch to add it now) **before** writing this task's tests. If you've already merged Task 1, do it as a single extra `addColumn` call in a small fixup commit before proceeding.

- [ ] **Step 1: Add `readAt` to `Messages` table + extend v6 → v7 migration**

In `lib/data/app_database.dart`, inside `class Messages extends Table { ... }`, add:

```dart
DateTimeColumn get readAt => dateTime().nullable()();
```

Update the v6 → v7 migration branch:

```dart
} else if (v == 6) {
  await m.createTable(outbox);
  await m.addColumn(messages, messages.deliveryState);
  await m.addColumn(messages, messages.readAt);   // NEW
}
```

Regenerate:

```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Commit this micro-fix:

```powershell
git add lib/data/app_database.dart lib/data/app_database.g.dart
git commit -m "data: also add messages.read_at in v6->v7 (consumed by Task 3)"
```

- [ ] **Step 2: Write failing tests in `test/data/chats_dao_test.dart`**

Append these tests to `test/data/chats_dao_test.dart` (the existing file already has `setUp`/`tearDown` for `db` + `dao`; reuse them).

```dart
group('delivery state', () {
  test('advanceDeliveryStateIfHigher only moves forward', () async {
    // Insert an outbound msg in default `sent` state.
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'm1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'hi', lamport: 1, sentAt: DateTime.now(),
    ));

    await dao.advanceDeliveryStateIfHigher('m1', DeliveryState.delivered);
    final r1 = (await dao.findMessageById('m1'))!;
    expect(r1.deliveryState, DeliveryState.delivered);

    // Out-of-order downgrade attempt — must be a no-op.
    await dao.advanceDeliveryStateIfHigher('m1', DeliveryState.sent);
    final r2 = (await dao.findMessageById('m1'))!;
    expect(r2.deliveryState, DeliveryState.delivered);

    // Direct sent -> read is allowed (skips delivered).
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'm2', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'hi2', lamport: 2, sentAt: DateTime.now(),
    ));
    await dao.advanceDeliveryStateIfHigher('m2', DeliveryState.read);
    expect((await dao.findMessageById('m2'))!.deliveryState, DeliveryState.read);
  });

  test('findMessageById round-trip and miss', () async {
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'mX', chatId: 'peerA', senderPubkeyHex: 'peerA',
      body: 'hi', lamport: 1, sentAt: DateTime.now(),
    ));
    expect((await dao.findMessageById('mX'))?.body, 'hi');
    expect(await dao.findMessageById('nope'), isNull);
  });

  test('watchDeliveryState emits on change', () async {
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'mW', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'watch', lamport: 1, sentAt: DateTime.now(),
    ));
    final events = <DeliveryState>[];
    final sub = dao.watchDeliveryState('mW').listen(events.add);
    await pumpEventQueue();
    await dao.advanceDeliveryStateIfHigher('mW', DeliveryState.delivered);
    await pumpEventQueue();
    await sub.cancel();
    expect(events, contains(DeliveryState.sent));
    expect(events, contains(DeliveryState.delivered));
  });
});

group('read tracking', () {
  test('unreadInboundMsgIds returns only unread inbound from peer', () async {
    final now = DateTime.now();
    // Inbound from peerA, unread:
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'i1', chatId: 'peerA', senderPubkeyHex: 'peerA',
      body: 'hi', lamport: 1, sentAt: now,
    ));
    // Inbound from peerA, already read:
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'i2', chatId: 'peerA', senderPubkeyHex: 'peerA',
      body: 'hi2', lamport: 2, sentAt: now,
      readAt: Value(now),
    ));
    // Outbound (self):
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'o1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'reply', lamport: 3, sentAt: now,
    ));
    // Inbound from a different peer:
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'i3', chatId: 'peerB', senderPubkeyHex: 'peerB',
      body: 'hey', lamport: 1, sentAt: now,
    ));

    final ids = await dao.unreadInboundMsgIds('peerA');
    expect(ids, ['i1']);
  });

  test('markRead sets read_at on every id in the list', () async {
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'r1', chatId: 'p', senderPubkeyHex: 'p',
      body: 'a', lamport: 1, sentAt: now,
    ));
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'r2', chatId: 'p', senderPubkeyHex: 'p',
      body: 'b', lamport: 2, sentAt: now,
    ));
    await dao.markRead(['r1', 'r2']);
    expect((await dao.findMessageById('r1'))!.readAt, isNotNull);
    expect((await dao.findMessageById('r2'))!.readAt, isNotNull);
  });
});
```

- [ ] **Step 3: Run to confirm failure**

```powershell
flutter test test/data/chats_dao_test.dart
```

Expected: build errors — methods undefined.

- [ ] **Step 4: Implement the new methods**

Append to `lib/data/chats_dao.dart` (before the closing `}` of `ChatsDao`):

```dart
/// Read a single message row by primary key. Used by `MessageService` to
/// dedup inbound text envelopes by msgId before insert.
Future<Message?> findMessageById(String msgId) =>
    (select(messages)..where((m) => m.id.equals(msgId))).getSingleOrNull();

/// Move `delivery_state` forward iff the new ordinal is strictly greater
/// than the existing one. Receipts are best-effort and can arrive in any
/// order (e.g. read before delivered after a retransmit); this guards the
/// monotonic invariant. `failed` is a terminal side-state — callers should
/// not invoke this with `failed`; use `updateDeliveryState` instead.
Future<void> advanceDeliveryStateIfHigher(
    String msgId, DeliveryState newState) async {
  final current = await findMessageById(msgId);
  if (current == null) return;
  if (current.deliveryState.index >= newState.index) return;
  await (update(messages)..where((m) => m.id.equals(msgId)))
      .write(MessagesCompanion(deliveryState: Value(newState)));
}

/// Force-set `delivery_state`. Used by the retransmitter to flip a row to
/// `failed` after the max attempt / 24h expiry. Skips the monotonic guard
/// because `failed` is terminal and intentionally a "downgrade" from `sent`.
Future<void> updateDeliveryState(String msgId, DeliveryState state) async {
  await (update(messages)..where((m) => m.id.equals(msgId)))
      .write(MessagesCompanion(deliveryState: Value(state)));
}

/// Stream a single message's `delivery_state`. The chat UI subscribes per
/// outbound bubble so tick changes re-render without a full chat refresh.
Stream<DeliveryState> watchDeliveryState(String msgId) =>
    (select(messages)..where((m) => m.id.equals(msgId)))
        .watchSingleOrNull()
        .map((row) => row?.deliveryState ?? DeliveryState.sent);

/// Returns ids of inbound (non-self) messages from [peerPubkeyHex] that
/// have not been locally marked read yet. Used by ChatThreadScreen to
/// batch a `read` receipt when the thread becomes visible.
Future<List<String>> unreadInboundMsgIds(String peerPubkeyHex) async {
  final rows = await (select(messages)
        ..where((m) =>
            m.senderPubkeyHex.equals(peerPubkeyHex) &
            m.chatId.equals(peerPubkeyHex) & // direct chats only
            m.readAt.isNull()))
      .get();
  return rows.map((r) => r.id).toList();
}

/// Mark a batch of messages locally read (sets `read_at = now`). Local-only;
/// the read receipt back to the peer is sent separately by the debouncer.
Future<void> markRead(List<String> msgIds) async {
  if (msgIds.isEmpty) return;
  final now = DateTime.now();
  await (update(messages)..where((m) => m.id.isIn(msgIds)))
      .write(MessagesCompanion(readAt: Value(now)));
}
```

- [ ] **Step 5: Run tests**

```powershell
flutter test test/data/chats_dao_test.dart
```

Expected: all new tests PASS; existing tests still pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/chats_dao.dart test/data/chats_dao_test.dart
git commit -m "chats_dao: receipt + dedup + read-tracking helpers"
```

---

## Task 4: `TextEnvelope.msgId` — required field + parse fallback for v0 peers

**Files:**
- Modify: `lib/chat/group_envelope.dart`
- Modify: `test/chat/group_envelope_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/chat/group_envelope_test.dart`:

```dart
group('TextEnvelope msgId', () {
  test('buildText round-trips msgId', () {
    final bytes = InnerEnvelope.buildText(
      chatId: 'peerA', lamport: 1, body: 'hi',
      msgId: '550e8400-e29b-41d4-a716-446655440000',
    );
    final parsed = InnerEnvelope.parse(bytes);
    expect(parsed, isA<TextEnvelope>());
    expect((parsed as TextEnvelope).msgId,
        '550e8400-e29b-41d4-a716-446655440000');
  });

  test('parse generates UUID when msgId missing (v0 backwards-compat)', () {
    final raw = utf8.encode(jsonEncode({
      'v': 1, 'type': 'text',
      'chatId': 'peerA', 'lamport': 1, 'body': 'old',
    }));
    final parsed = InnerEnvelope.parse(raw) as TextEnvelope;
    expect(parsed.msgId, isNotEmpty);
    expect(parsed.msgId.length, 36); // UUID v4 length
  });

  test('parse treats empty-string msgId as missing', () {
    final raw = utf8.encode(jsonEncode({
      'v': 1, 'type': 'text',
      'chatId': 'peerA', 'lamport': 1, 'body': 'x', 'msgId': '',
    }));
    final parsed = InnerEnvelope.parse(raw) as TextEnvelope;
    expect(parsed.msgId.length, 36);
  });
});
```

(If `dart:convert` / `package:uuid` aren't imported in the test file already, add them at the top.)

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/group_envelope_test.dart
```

Expected: build error — `msgId` is not a named parameter / field.

- [ ] **Step 3: Add msgId to `TextEnvelope` + `buildText` + parse**

In `lib/chat/group_envelope.dart`:

Add a uuid import at the top:

```dart
import 'package:uuid/uuid.dart';
```

Update the `TextEnvelope` class:

```dart
class TextEnvelope implements InnerEnvelope {
  TextEnvelope({
    required this.chatId,
    required this.lamport,
    required this.body,
    required this.msgId,                  // NEW
    this.senderDisplayName,
  });
  @override final String chatId;
  @override final int lamport;
  final String body;
  final String msgId;                     // NEW
  @override final String? senderDisplayName;
}
```

Update the `case 'text':` branch in `InnerEnvelope.parse`:

```dart
case 'text':
  final body = raw['body'];
  if (body is! String) throw const FormatException('text missing body');
  // Pre-Phase-2 peers may omit msgId. Generate a local UUID so the
  // typed envelope can still be constructed; dedup against the same
  // peer's retransmits is impossible (no canonical id), but no message
  // is lost. Spec §10 backwards-compat clause.
  final msgIdRaw = raw['msgId'];
  final msgId = (msgIdRaw is String && msgIdRaw.isNotEmpty)
      ? msgIdRaw
      : const Uuid().v4();
  return TextEnvelope(
    chatId: chatId, lamport: lamport, body: body, msgId: msgId,
    senderDisplayName: senderDisplayName,
  );
```

Update `InnerEnvelope.buildText`:

```dart
static List<int> buildText({
  required String chatId,
  required int lamport,
  required String body,
  required String msgId,                  // NEW
  String? senderDisplayName,
}) {
  return utf8.encode(jsonEncode({
    'v': 1, 'type': 'text',
    'chatId': chatId, 'lamport': lamport, 'body': body,
    'msgId': msgId,                       // NEW
    'senderDisplayName': ?senderDisplayName,
  }));
}
```

- [ ] **Step 4: Update every existing call site of `buildText` to pass msgId**

There are call sites in `lib/chat/message_service.dart`:
- `sendText` (line ~103) — will receive its own real msgId in Task 6; for now pass `const Uuid().v4()` as a placeholder to keep the build green.
- `sendGroupText` (line ~260) — also pass `const Uuid().v4()`. Group msgId stays a one-shot per spec §7l.

Add `import 'package:uuid/uuid.dart';` and a `static const _uuid = Uuid();` member if not present (it already is — line 60).

Touch up each `InnerEnvelope.buildText(...)` invocation to add `msgId: _uuid.v4(),`. (Task 6 will replace `sendText`'s with the real msgId.)

- [ ] **Step 5: Run all tests**

```powershell
flutter test
```

Expected: all PASS. The placeholder UUIDs in `message_service.dart` don't break any test because no existing test asserts on the inner envelope's msgId yet.

- [ ] **Step 6: Commit**

```powershell
git add lib/chat/group_envelope.dart lib/chat/message_service.dart `
        test/chat/group_envelope_test.dart
git commit -m "envelope: TextEnvelope.msgId with v0 backwards-compat fallback"
```

---

## Task 5: `DeliveryReceiptEnvelope` + parse + `buildDeliveryReceipt`

**Files:**
- Modify: `lib/chat/group_envelope.dart`
- Modify: `test/chat/group_envelope_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/chat/group_envelope_test.dart`:

```dart
group('DeliveryReceiptEnvelope', () {
  test('buildDeliveryReceipt round-trip with delivered kind', () {
    final at = DateTime.utc(2026, 5, 26, 15, 30, 45);
    final bytes = InnerEnvelope.buildDeliveryReceipt(
      chatId: 'peerA',
      msgIds: ['uuid-1', 'uuid-2'],
      kind: ReceiptKind.delivered,
      at: at,
    );
    final parsed = InnerEnvelope.parse(bytes);
    expect(parsed, isA<DeliveryReceiptEnvelope>());
    final r = parsed as DeliveryReceiptEnvelope;
    expect(r.chatId, 'peerA');
    expect(r.lamport, 0);
    expect(r.msgIds, ['uuid-1', 'uuid-2']);
    expect(r.kind, ReceiptKind.delivered);
    expect(r.at, at);
  });

  test('parse rejects unknown kind', () {
    final raw = utf8.encode(jsonEncode({
      'v': 1, 'type': 'delivery_receipt',
      'chatId': 'p', 'lamport': 0,
      'msgIds': ['x'],
      'kind': 'bogus',
      'at': DateTime.utc(2026, 1, 1).toIso8601String(),
    }));
    expect(() => InnerEnvelope.parse(raw), throwsFormatException);
  });

  test('parse rejects empty msgIds', () {
    final raw = utf8.encode(jsonEncode({
      'v': 1, 'type': 'delivery_receipt',
      'chatId': 'p', 'lamport': 0,
      'msgIds': <String>[],
      'kind': 'delivered',
      'at': DateTime.utc(2026, 1, 1).toIso8601String(),
    }));
    expect(() => InnerEnvelope.parse(raw), throwsFormatException);
  });
});
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/group_envelope_test.dart
```

Expected: `DeliveryReceiptEnvelope` / `ReceiptKind` / `buildDeliveryReceipt` undefined.

- [ ] **Step 3: Implement the new envelope kind**

Append to `lib/chat/group_envelope.dart` (after the existing envelope classes, before EOF):

```dart
enum ReceiptKind { delivered, read }

class DeliveryReceiptEnvelope implements InnerEnvelope {
  DeliveryReceiptEnvelope({
    required this.chatId,
    required this.msgIds,
    required this.kind,
    required this.at,
    this.senderDisplayName,
  });

  factory DeliveryReceiptEnvelope._fromJson(Map<String, dynamic> raw) {
    final msgIds = (raw['msgIds'] as List?)?.cast<String>() ?? const [];
    if (msgIds.isEmpty) {
      throw const FormatException('delivery_receipt missing msgIds');
    }
    final kindStr = raw['kind'];
    final kind = switch (kindStr) {
      'delivered' => ReceiptKind.delivered,
      'read' => ReceiptKind.read,
      _ => throw FormatException('unknown receipt kind: $kindStr'),
    };
    final atStr = raw['at'];
    if (atStr is! String) {
      throw const FormatException('delivery_receipt missing at');
    }
    return DeliveryReceiptEnvelope(
      chatId: raw['chatId'] as String,
      msgIds: msgIds,
      kind: kind,
      at: DateTime.parse(atStr),
      senderDisplayName: raw['senderDisplayName'] as String?,
    );
  }

  @override final String chatId;
  // Receipts don't advance the chat's lamport clock — they're metadata.
  @override int get lamport => 0;
  final List<String> msgIds;
  final ReceiptKind kind;
  final DateTime at;
  @override final String? senderDisplayName;
}
```

Add a static builder on `InnerEnvelope` (alongside `buildText` etc.):

```dart
static List<int> buildDeliveryReceipt({
  required String chatId,
  required List<String> msgIds,
  required ReceiptKind kind,
  required DateTime at,
  String? senderDisplayName,
}) {
  return utf8.encode(jsonEncode({
    'v': 1, 'type': 'delivery_receipt',
    'chatId': chatId, 'lamport': 0,
    'msgIds': msgIds,
    'kind': kind == ReceiptKind.read ? 'read' : 'delivered',
    'at': at.toUtc().toIso8601String(),
    'senderDisplayName': ?senderDisplayName,
  }));
}
```

Add the parse branch in `InnerEnvelope.parse`, just before the `default:` case:

```dart
case 'delivery_receipt':
  return DeliveryReceiptEnvelope._fromJson(raw);
```

- [ ] **Step 4: Run all envelope tests**

```powershell
flutter test test/chat/group_envelope_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/group_envelope.dart test/chat/group_envelope_test.dart
git commit -m "envelope: DeliveryReceiptEnvelope kind + parse + builder"
```

---

## Task 6: `MessageService.sendText` — outbox row + real msgId

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `test/chat/message_service_test.dart`

- [ ] **Step 1: Add `outboxDao` to the `MessageService` constructor**

In `lib/chat/message_service.dart`, add the field and the constructor parameter:

```dart
final OutboxDao outboxDao;     // NEW

MessageService({
  required this.crypto,
  required this.relay,
  required this.dao,
  required this.peerBundleDao,
  required this.outboxDao,     // NEW
  required this.myPubkeyHex,
  // ... existing params unchanged ...
}) {
  _sub = relay.inbound.listen(_onInbound);
}
```

Add the import at the top: `import '../data/outbox_dao.dart';`

The provider in Task 12 will pass it; for now this change breaks `message_service_test.dart` and the `messageServiceProvider`. Patch both to pass an in-memory `OutboxDao(db)` so the build stays green.

- [ ] **Step 2: Write failing tests**

Append to `test/chat/message_service_test.dart`:

```dart
test('sendText writes an outbox row keyed by msgId', () async {
  // ... existing test setUp constructs `svc` against a fake relay + DB ...
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'hello');

  // The outbox row should exist for the just-sent message. We don't know the
  // msgId up front because sendText generates it internally, so look up by
  // peer + count.
  final allRows = await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)));
  final peerRows = allRows.where((r) => r.peerPubkeyHex == 'peerA').toList();
  expect(peerRows, hasLength(1));
  final msgId = peerRows.first.msgId;

  // The messages.id row must match the outbox msgId.
  final msgRow = await svc.dao.findMessageById(msgId);
  expect(msgRow, isNotNull);
  expect(msgRow!.senderPubkeyHex, svc.myPubkeyHex);
  expect(msgRow.body, 'hello');
});

test('sendText sets initial nextRetryAt to createdAt + 30s', () async {
  final before = DateTime.now();
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'x');
  final after = DateTime.now();
  final rows = await svc.outboxDao.dueBefore(after.add(const Duration(days: 1)));
  final row = rows.firstWhere((r) => r.peerPubkeyHex == 'peerA');
  // Allow a small clock window — but the row's nextRetryAt must be ~30s
  // ahead of createdAt.
  final delta = row.nextRetryAt.difference(row.createdAt);
  expect(delta.inSeconds, inInclusiveRange(28, 32));
  expect(row.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue);
});
```

- [ ] **Step 3: Run tests to confirm failure**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: failures — outbox row missing.

- [ ] **Step 4: Update `_persistOutbound` to take msgId, and update `sendText`**

Change `_persistOutbound` signature:

```dart
Future<void> _persistOutbound(
  String peerPubkeyHex,
  String body,
  int lamport,
  String msgId,             // NEW — use this as the messages.id
) async {
  final now = DateTime.now();
  await dao.insertMessage(MessagesCompanion.insert(
    id: msgId,              // CHANGED — was _uuid.v4()
    chatId: peerPubkeyHex,
    senderPubkeyHex: myPubkeyHex,
    body: body,
    lamport: lamport,
    sentAt: now,
    kind: const Value('text'),
  ));
  await dao.updateLastMessage(peerPubkeyHex, _preview(body), now);
}
```

Update `sendText` (replace the body from `await dao.ensureDirectChat(...)` down to the encrypt/send block):

```dart
Future<void> sendText({
  required String peerPubkeyHex,
  required String body,
}) async {
  _log('sendText peer=${_short(peerPubkeyHex)} bodyLen=${body.length}');
  await dao.ensureDirectChat(peerPubkeyHex);
  await _maybeSendOwnBundle(peerPubkeyHex);

  final msgId = _uuid.v4();                         // NEW — single canonical id
  final lamport = await dao.bumpLamport(peerPubkeyHex);
  final myName = await _currentDisplayName();
  final jsonBytes = InnerEnvelope.buildText(
    chatId: myPubkeyHex,
    lamport: lamport,
    body: body,
    senderDisplayName: myName,
    msgId: msgId,                                   // NEW
  );

  await _persistOutbound(peerPubkeyHex, body, lamport, msgId);

  // Outbox row goes in BEFORE _encryptAndSend. If encrypt or send throws,
  // the row stays; the retransmitter picks it up on its next sweep.
  // If send succeeds, the row stays in implied-`sent` state until a
  // `delivered` receipt arrives and deletes it (Task 8).
  final now = DateTime.now();
  await outboxDao.insert(
    msgId: msgId,
    peerPubkeyHex: peerPubkeyHex,
    envelopeBytes: jsonBytes,
    createdAt: now,
    nextRetryAt: now.add(const Duration(seconds: 30)),
  );

  final peerState = await peerBundleDao.get(peerPubkeyHex);
  if (peerState?.peerBundleReceivedAt == null) {
    (_pendingByPeer[peerPubkeyHex] ??= <List<int>>[]).add(jsonBytes);
    _log('queued (no peer bundle yet) peer=${_short(peerPubkeyHex)} '
        'queueDepth=${_pendingByPeer[peerPubkeyHex]!.length}');
    return;
  }
  try {
    await _encryptAndSend(peerPubkeyHex, jsonBytes);
    _log('encrypted+sent peer=${_short(peerPubkeyHex)} msgId=${_short(msgId)}');
  } catch (e, st) {
    _log('ENCRYPT FAIL peer=${_short(peerPubkeyHex)} err=$e\n$st');
    // Do not rethrow — the outbox row is the recovery handle. The caller
    // already got UI optimism from _persistOutbound. The retransmitter
    // will retry; if it stays failing for 24h, the tick goes to `failed`.
  }
}
```

> **Behavior change worth flagging:** the existing `sendText` rethrows on encrypt failure. After this task, encrypt failures are logged and swallowed because the outbox row is the durable recovery handle. Any caller relying on a thrown exception for UX-error display must move to watching `messages.deliveryState` for the `failed` transition instead. The only known caller is `composer.dart` which currently doesn't show send errors; no caller change needed.

- [ ] **Step 5: Run tests**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: new tests PASS; existing sendText tests still pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/chat/message_service.dart test/chat/message_service_test.dart
git commit -m "message_service: sendText persists outbox + uses canonical msgId"
```

---

## Task 7: Inbound text dedup + receipt enqueue (always, even on dup)

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `test/chat/message_service_test.dart`

This task introduces the dedup branch in `_handleDeliver` for `TextEnvelope`. It also makes the `messages.id` insert path use `inner.msgId` (canonical id) instead of `_uuid.v4()`. Receipt enqueueing happens via the debouncer added in Task 10 — for this task, expose a minimal callback hook that Task 10 will plug in.

- [ ] **Step 1: Add a `receiptDebouncer` field as `late` so Task 10 can wire it**

In `MessageService` (right next to `_unackedByPeer`):

```dart
// Late-init so messageServiceProvider can hand back a debouncer that
// reaches back into `this`. Calling `enqueueDelivered` before assignment
// is a programming error and will throw LateInitializationError —
// covered by the provider lifecycle in Task 12.
late DeliveryReceiptDebouncer receiptDebouncer;
```

Add the import (the class lives in `lib/chat/delivery_receipt_debouncer.dart`, created in Task 10 — for this task add a stub class so the build is green):

```dart
import 'delivery_receipt_debouncer.dart';
```

And in `lib/chat/delivery_receipt_debouncer.dart` write a minimal stub:

```dart
// Stubbed in Task 7. Full implementation lands in Task 10.
class DeliveryReceiptDebouncer {
  DeliveryReceiptDebouncer(this._noop);
  // ignore: unused_field
  final dynamic _noop;
  void enqueueDelivered({required String peer, required String msgId}) {}
  void enqueueRead({required String peer, required List<String> msgIds}) {}
  Future<void> flushAllForTest() async {}
}
```

- [ ] **Step 2: Write failing tests**

Append to `test/chat/message_service_test.dart`:

```dart
test('inbound text persists with id = inner.msgId', () async {
  // Build an inner envelope from peerA addressed to me.
  final inner = InnerEnvelope.buildText(
    chatId: 'peerA', lamport: 1, body: 'hello',
    msgId: 'fixed-msg-1',
  );
  // Push it through the fake relay's deliver pipe.
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'peerA', envelope: inner));
  await pumpEventQueue();

  final row = await svc.dao.findMessageById('fixed-msg-1');
  expect(row, isNotNull);
  expect(row!.body, 'hello');
  expect(row.senderPubkeyHex, 'peerA');
});

test('duplicate inbound text is dropped silently', () async {
  final inner = InnerEnvelope.buildText(
    chatId: 'peerA', lamport: 1, body: 'hi',
    msgId: 'dup-1',
  );
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'peerA', envelope: inner));
  await pumpEventQueue();
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'peerA', envelope: inner));
  await pumpEventQueue();

  // Only one row.
  final rows = (await db.select(db.messages).get())
      .where((r) => r.id == 'dup-1').toList();
  expect(rows, hasLength(1));
});
```

(Replace `fakeRelay`/`db` with whatever the existing test harness uses — `message_service_test.dart` already exercises this path.)

- [ ] **Step 3: Run to confirm failure**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: the persist-with-id test fails because today's code uses `_uuid.v4()`.

- [ ] **Step 4: Patch the TextEnvelope branch in `_handleDeliver`**

Find the existing text-handling block at the end of `_handleDeliver` (the lines around `if (inner is! TextEnvelope) ...` through the `insertMessage` call). Replace the insert path:

```dart
if (inner is! TextEnvelope) {
  _log('unhandled_inner_type type=${inner.runtimeType}');
  return;
}

// NEW: dedup-by-(sender, msgId). Spec §7d. A duplicate inbound with the
// same (sender, msgId) pair is dropped silently because Layer A flush
// and Layer B retransmit can both legitimately deliver the same envelope
// in a race. We still enqueue a `delivered` receipt because the sender's
// original receipt might have been lost — receipts are best-effort.
final existing = await dao.findMessageById(inner.msgId);
if (existing != null && existing.senderPubkeyHex == frame.fromPubkeyHex) {
  _log('dedup_inbound msgId=${_short(inner.msgId)} '
      'from=${_short(frame.fromPubkeyHex)}');
  receiptDebouncer.enqueueDelivered(
      peer: frame.fromPubkeyHex, msgId: inner.msgId);
  return;
}

// ... existing chat-kind switch + spoof-guard checks unchanged ...

// In the insertMessage call below, the id MUST be inner.msgId for direct
// chats (sender's canonical id, used as the dedup key). For groups we
// keep inner.msgId too — collision is astronomically rare; if it ever
// happens, insertOrIgnore drops the second row, which is acceptable for
// ~10 users and the dedup branch above will not falsely match because
// groups don't send receipts in this phase.
await dao.insertMessage(MessagesCompanion.insert(
  id: inner.msgId,                        // CHANGED — was _uuid.v4()
  chatId: inner.chatId,
  senderPubkeyHex: frame.fromPubkeyHex,
  body: body,
  lamport: lamport,
  sentAt: now,
  receivedAt: Value(now),
  kind: const Value('text'),
));
// ... existing updateLastMessage + notification logic unchanged ...

// NEW: enqueue a delivered receipt for direct chats only. Per spec §7l,
// groups don't get receipts in this phase.
if (chat.kind == 'direct') {
  receiptDebouncer.enqueueDelivered(
      peer: frame.fromPubkeyHex, msgId: inner.msgId);
}
```

- [ ] **Step 5: Run tests**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: both new tests PASS; all existing inbound-text tests still pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/chat/message_service.dart lib/chat/delivery_receipt_debouncer.dart `
        test/chat/message_service_test.dart
git commit -m "message_service: dedup inbound text + enqueue delivered receipt"
```

---

## Task 8: Inbound `delivery_receipt` handler — monotonic state, spoof guard, outbox delete

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `test/chat/message_service_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `test/chat/message_service_test.dart`:

```dart
test('inbound delivered receipt advances state and deletes outbox row', () async {
  // 1) Send a message so we have an outbox row + a messages row.
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'ping');
  final allOutbox = await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)));
  final msgId = allOutbox.first.msgId;

  // 2) Inject a delivery_receipt from peerA for that msgId.
  final receipt = InnerEnvelope.buildDeliveryReceipt(
    chatId: svc.myPubkeyHex,
    msgIds: [msgId],
    kind: ReceiptKind.delivered,
    at: DateTime.now(),
  );
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'peerA', envelope: receipt));
  await pumpEventQueue();

  // 3) State advanced, outbox row gone.
  final row = await svc.dao.findMessageById(msgId);
  expect(row!.deliveryState, DeliveryState.delivered);
  expect(await svc.outboxDao.findByMsgId(msgId), isNull);
});

test('read receipt allows direct sent -> read transition', () async {
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'p');
  final msgId = (await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)))).first.msgId;

  final r = InnerEnvelope.buildDeliveryReceipt(
    chatId: svc.myPubkeyHex,
    msgIds: [msgId],
    kind: ReceiptKind.read,
    at: DateTime.now(),
  );
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'peerA', envelope: r));
  await pumpEventQueue();

  expect((await svc.dao.findMessageById(msgId))!.deliveryState,
      DeliveryState.read);
});

test('forged receipt from wrong peer is ignored', () async {
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'p');
  final msgId = (await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)))).first.msgId;

  final r = InnerEnvelope.buildDeliveryReceipt(
    chatId: svc.myPubkeyHex,
    msgIds: [msgId],
    kind: ReceiptKind.delivered,
    at: DateTime.now(),
  );
  fakeRelay.inject(DeliverFrame(fromPubkeyHex: 'attackerX', envelope: r));
  await pumpEventQueue();

  // State unchanged, outbox row still present.
  expect((await svc.dao.findMessageById(msgId))!.deliveryState,
      DeliveryState.sent);
  expect(await svc.outboxDao.findByMsgId(msgId), isNotNull);
});

test('delivered after read does not downgrade tick', () async {
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'p');
  final msgId = (await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)))).first.msgId;

  // Read first (legal — receipts can reorder).
  fakeRelay.inject(DeliverFrame(
    fromPubkeyHex: 'peerA',
    envelope: InnerEnvelope.buildDeliveryReceipt(
      chatId: svc.myPubkeyHex, msgIds: [msgId],
      kind: ReceiptKind.read, at: DateTime.now()),
  ));
  await pumpEventQueue();
  // Then delivered (out-of-order retransmit).
  fakeRelay.inject(DeliverFrame(
    fromPubkeyHex: 'peerA',
    envelope: InnerEnvelope.buildDeliveryReceipt(
      chatId: svc.myPubkeyHex, msgIds: [msgId],
      kind: ReceiptKind.delivered, at: DateTime.now()),
  ));
  await pumpEventQueue();

  expect((await svc.dao.findMessageById(msgId))!.deliveryState,
      DeliveryState.read);
});
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: build error — `_handleDeliveryReceipt` not yet defined; assertions fail.

- [ ] **Step 3: Implement the handler**

In `lib/chat/message_service.dart`, add a dispatch branch in `_handleDeliver` after the existing envelope-kind branches (`MemberLeaveEnvelope`) and before `if (inner is! TextEnvelope)`:

```dart
if (inner is DeliveryReceiptEnvelope) {
  await _handleDeliveryReceipt(frame, inner);
  return;
}
```

Add the handler method after `_handleMemberLeave`:

```dart
/// Inbound `delivery_receipt` — sender is acking message(s) we sent.
/// Spec §7e: spoof-guarded, monotonic, outbox row deleted on either kind.
Future<void> _handleDeliveryReceipt(
  DeliverFrame frame,
  DeliveryReceiptEnvelope inner,
) async {
  for (final mid in inner.msgIds) {
    final outboxRow = await outboxDao.findByMsgId(mid);
    if (outboxRow == null) {
      // Either the original is older than retention, or peer clock drift,
      // or this is a duplicate receipt arriving after the row was already
      // deleted. All benign; log + skip.
      _log('receipt_no_outbox msgId=${_short(mid)} '
          'from=${_short(frame.fromPubkeyHex)}');
      continue;
    }
    if (outboxRow.peerPubkeyHex != frame.fromPubkeyHex) {
      // Spoof guard — only the peer we originally sent to may ack.
      _log('receipt_peer_mismatch msgId=${_short(mid)} '
          'sentTo=${_short(outboxRow.peerPubkeyHex)} '
          'from=${_short(frame.fromPubkeyHex)}');
      continue;
    }
    final newState = inner.kind == ReceiptKind.read
        ? DeliveryState.read
        : DeliveryState.delivered;
    await dao.advanceDeliveryStateIfHigher(mid, newState);
    await outboxDao.delete(mid);
    _log('receipt_applied msgId=${_short(mid)} '
        'kind=${inner.kind.name} from=${_short(frame.fromPubkeyHex)}');
  }
}
```

- [ ] **Step 4: Run tests**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: all new tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/message_service.dart test/chat/message_service_test.dart
git commit -m "message_service: handle delivery_receipt — monotonic state + outbox drain"
```

---

## Task 9: Drop `_unackedByPeer` — fire wake unconditionally on `recipient_offline`

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `test/chat/message_service_test.dart`

Per spec §7m, the in-memory `_unackedByPeer` heuristic is now redundant. Layer A queues every undelivered envelope server-side, and the outbox + retransmitter drives client recovery. The wake fallback is idempotent server-side (the existing `wake_client.dart` /v1/wake endpoint), so firing on every `recipient_offline` is safe.

- [ ] **Step 1: Update / add tests reflecting the new behavior**

Either drop or rewrite the existing test that asserts `_unackedByPeer` gates wake. The new test should be:

```dart
test('recipient_offline fires wake without an in-flight envelope match', () async {
  // Force a recipient_offline error from the relay.
  fakeRelay.inject(ErrorFrame(
    code: 'recipient_offline',
    message: 'peerA',
    toPubkeyHex: 'peerA',
  ));
  await pumpEventQueue();

  // The fake wake client should have received exactly one call.
  expect(fakeWake.calls, hasLength(1));
  expect(fakeWake.calls.single.recipientPubkeyHex, 'peerA');
  // Envelope is empty (no in-flight queue to drain); server side this
  // still triggers an FCM push if a phonebook entry exists.
  expect(fakeWake.calls.single.envelope, isEmpty);
});
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: test fails — wake is still gated on `_unackedByPeer`.

- [ ] **Step 3: Rewrite `_handleError`**

Replace the entire `_handleError` method body:

```dart
Future<void> _handleError(ErrorFrame frame) async {
  if (frame.code != 'recipient_offline' || frame.toPubkeyHex == null) {
    _log('inbound error code=${frame.code} msg=${frame.message} (no wake)');
    return;
  }
  final peer = frame.toPubkeyHex!;
  final wakeClient = wake;
  if (wakeClient == null) {
    _log('wake_unconfigured peer=${_short(peer)}');
    return;
  }
  // Spec §7m — wake fires on every recipient_offline. Server-side queue
  // (Phase 10.4.3a) covers the delivery; this wake is the "tap the
  // recipient to come online" hint. Empty envelope is fine — server's
  // wakeOfflineRecipient looks up the phonebook entry and pushes a
  // marker-only FCM that the recipient's BG isolate reacts to.
  _log('wake_dispatching peer=${_short(peer)} (unconditional)');
  final result = await wakeClient.wake(
    senderPubkeyHex: myPubkeyHex,
    recipientPubkeyHex: peer,
    envelope: const <int>[],
  );
  switch (result.status) {
    case WakeStatus.ok:
      _log('wake_dispatched peer=${_short(peer)}');
    case WakeStatus.recipientNotRegistered:
      _log('wake_failed_no_phonebook peer=${_short(peer)}');
    case WakeStatus.fcmError:
      _log('wake_failed_fcm peer=${_short(peer)} detail=${result.detail}');
    case WakeStatus.networkError:
      _log('wake_failed_network peer=${_short(peer)} detail=${result.detail}');
    case WakeStatus.serverError:
      _log('wake_failed_server peer=${_short(peer)} detail=${result.detail}');
    case WakeStatus.unauthorized:
      _log('wake_failed_unauthorized peer=${_short(peer)} detail=${result.detail}');
  }
}
```

Delete the `_unackedByPeer` field declaration:

```dart
// REMOVE this whole block:
// final Map<String, List<List<int>>> _unackedByPeer = <String, List<List<int>>>{};
```

Delete the `_unackedByPeer.remove(...)` call in `_onInbound`:

```dart
void _onInbound(RelayFrame frame) {
  if (frame is DeliverFrame) {
    _handleDeliver(frame);
  } else if (frame is ErrorFrame) {
    _handleError(frame);
  }
}
```

Delete the `_unackedByPeer[peerPubkeyHex] ??= ...` write in `_encryptAndSend`:

```dart
Future<void> _encryptAndSend(String peerPubkeyHex, List<int> plaintext) async {
  final ciphertext = await crypto.encrypt(
    peerPubkeyHex: peerPubkeyHex,
    plaintext: plaintext,
  );
  final envelope = EnvelopeWire.wrapMessage(ciphertext);
  await relay.send(
    toPubkeyHex: peerPubkeyHex,
    envelope: envelope,
  );
}
```

Delete the `_unackedByPeer.remove(peerPubkeyHex)` call in `forgetPeer`. (Task 16 adds the new outbox cascade.)

- [ ] **Step 4: Run all message_service tests**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: all tests PASS, including the rewritten wake test.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/message_service.dart test/chat/message_service_test.dart
git commit -m "message_service: drop _unackedByPeer, fire wake unconditionally"
```

---

## Task 10: `DeliveryReceiptDebouncer` — 250 ms batch (delivered) + immediate (read)

**Files:**
- Replace: `lib/chat/delivery_receipt_debouncer.dart` (stub from Task 7 gets full impl)
- Create: `test/chat/delivery_receipt_debouncer_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/chat/delivery_receipt_debouncer_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_v3/chat/delivery_receipt_debouncer.dart';
import 'package:app_v3/chat/group_envelope.dart';

/// Records the envelopes the debouncer ships, so tests can assert without
/// touching a real CryptoService / RelayClient.
class _RecordingSender implements ReceiptSender {
  final calls = <_Call>[];
  String? currentDisplayName;
  @override
  Future<String?> currentDisplayName() async => currentDisplayName;
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

  tearDown(() async => deb.dispose());

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
    // No delay — the call returns synchronously and the sender already saw it.
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
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/delivery_receipt_debouncer_test.dart
```

Expected: build errors / no `ReceiptSender` / `dispose` undefined.

- [ ] **Step 3: Implement the real debouncer**

Replace `lib/chat/delivery_receipt_debouncer.dart` (stub from Task 7) with:

```dart
import 'dart:async';

import 'group_envelope.dart';

/// Indirection the debouncer talks through, so tests can swap a recorder for
/// the real `MessageService._encryptAndSend` + `_currentDisplayName`.
abstract class ReceiptSender {
  Future<String?> currentDisplayName();
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes);
}

class _PendingBatch {
  _PendingBatch();
  final msgIds = <String>{};
  Timer? timer;
}

/// Per-peer accumulator that batches `delivered` msgIds within a 250 ms
/// window. `read` flushes immediately because reads are already batched at
/// the source (chat-thread visibility collects all unread ids in one shot).
class DeliveryReceiptDebouncer {
  DeliveryReceiptDebouncer(this._sender);

  final ReceiptSender _sender;
  final _byPeer = <String, _PendingBatch>{};
  static const _delivereDelay = Duration(milliseconds: 250);

  void enqueueDelivered({required String peer, required String msgId}) {
    final batch = _byPeer.putIfAbsent(peer, _PendingBatch.new);
    batch.msgIds.add(msgId);
    batch.timer ??= Timer(_delivereDelay, () => _flushDelivered(peer));
  }

  void enqueueRead({required String peer, required List<String> msgIds}) {
    if (msgIds.isEmpty) return;
    // Fire-and-forget; failures are logged but not awaited (caller is a UI
    // visibility hook, must not block the frame).
    _send(peer, List<String>.from(msgIds), ReceiptKind.read);
  }

  Future<void> _flushDelivered(String peer) async {
    final batch = _byPeer.remove(peer);
    if (batch == null || batch.msgIds.isEmpty) return;
    batch.timer?.cancel();
    await _send(peer, batch.msgIds.toList(), ReceiptKind.delivered);
  }

  Future<void> _send(
      String peer, List<String> msgIds, ReceiptKind kind) async {
    final myName = await _sender.currentDisplayName();
    final envBytes = InnerEnvelope.buildDeliveryReceipt(
      chatId: peer,
      msgIds: msgIds,
      kind: kind,
      at: DateTime.now(),
      senderDisplayName: myName,
    );
    try {
      await _sender.encryptAndSend(peer, envBytes);
    } catch (e, st) {
      // Best-effort. If the receipt send fails, the original sender's
      // retransmitter eventually retries the original message; we'll send
      // a fresh receipt then. No retry queue here on purpose — receipts
      // pile up infinitely if a peer is permanently offline.
      // ignore: avoid_print
      print('[DRD] receipt_send_fail peer=$peer kind=$kind err=$e\n$st');
    }
  }

  /// Test-only — drain every pending batch synchronously.
  Future<void> flushAllForTest() async {
    final peers = _byPeer.keys.toList();
    for (final p in peers) {
      await _flushDelivered(p);
    }
  }

  void dispose() {
    for (final b in _byPeer.values) {
      b.timer?.cancel();
    }
    _byPeer.clear();
  }
}
```

- [ ] **Step 4: Run tests**

```powershell
flutter test test/chat/delivery_receipt_debouncer_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/delivery_receipt_debouncer.dart `
        test/chat/delivery_receipt_debouncer_test.dart
git commit -m "debouncer: 250ms batch for delivered, immediate for read"
```

---

## Task 11: `OutboxRetransmitter` — 10 s sweep + ladder backoff + 24 h expiry

**Files:**
- Create: `lib/chat/outbox_retransmitter.dart`
- Create: `test/chat/outbox_retransmitter_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/chat/outbox_retransmitter_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/chat/outbox_retransmitter.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/outbox_dao.dart';

/// Captures send attempts so tests can inject success/failure outcomes.
class _RecordingSender implements RetransmitSender {
  final calls = <_Sent>[];
  bool fail = false;
  @override
  Future<void> sendOnce(String peer, List<int> envelopeBytes) async {
    calls.add(_Sent(peer, envelopeBytes));
    if (fail) throw Exception('send failed');
  }
}

class _Sent {
  _Sent(this.peer, this.bytes);
  final String peer;
  final List<int> bytes;
}

void main() {
  late AppDatabase db;
  late OutboxDao outbox;
  late ChatsDao chats;
  late _RecordingSender sender;
  late OutboxRetransmitter rx;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxDao(db);
    chats = ChatsDao(db);
    sender = _RecordingSender();
    rx = OutboxRetransmitter(outbox: outbox, chats: chats, sender: sender);
  });

  tearDown(() async {
    rx.stop();
    await db.close();
  });

  Future<String> _seed({
    required DateTime createdAt,
    required DateTime nextRetryAt,
  }) async {
    final id = 'm-${createdAt.microsecondsSinceEpoch}';
    await chats.insertMessage(MessagesCompanion.insert(
      id: id, chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'x', lamport: 1, sentAt: createdAt,
    ));
    await outbox.insert(
      msgId: id, peerPubkeyHex: 'peerA', envelopeBytes: [1, 2, 3],
      createdAt: createdAt, nextRetryAt: nextRetryAt,
    );
    return id;
  }

  test('sweep retransmits only rows past nextRetryAt', () async {
    final t = DateTime.now();
    final dueId = await _seed(
      createdAt: t.subtract(const Duration(minutes: 5)),
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    final notDueId = await _seed(
      createdAt: t,
      nextRetryAt: t.add(const Duration(minutes: 1)),
    );
    await rx.sweepOnceForTest(now: t);
    expect(sender.calls.map((c) => c.peer).toList(), ['peerA']);
    expect(sender.calls.single.bytes, [1, 2, 3]);

    // dueId stays in the outbox (Push success doesn't delete it — that's
    // the receipt's job), but its attempt + nextRetryAt have advanced.
    final dueRow = await outbox.findByMsgId(dueId);
    expect(dueRow!.attempt, 1);
    expect(dueRow.nextRetryAt.isAfter(t), isTrue);
    // notDueId untouched.
    expect((await outbox.findByMsgId(notDueId))!.attempt, 0);
  });

  test('ladder picks 30s / 60s / 5m / 30m / 1h then sticks at 1h', () {
    final t = DateTime(2026, 5, 26, 12, 0, 0);
    expect(OutboxRetransmitter.nextRetryAt(attempt: 1, now: t),
        t.add(const Duration(seconds: 30)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 2, now: t),
        t.add(const Duration(seconds: 60)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 3, now: t),
        t.add(const Duration(minutes: 5)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 4, now: t),
        t.add(const Duration(minutes: 30)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 5, now: t),
        t.add(const Duration(hours: 1)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 99, now: t),
        t.add(const Duration(hours: 1)));
  });

  test('24h expiry marks the row failed and removes it from outbox', () async {
    final t = DateTime.now();
    final id = await _seed(
      createdAt: t.subtract(const Duration(hours: 25)),
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    await rx.sweepOnceForTest(now: t);
    expect(await outbox.findByMsgId(id), isNull);
    expect((await chats.findMessageById(id))!.deliveryState,
        DeliveryState.failed);
  });

  test('send failure still bumps attempt — caller retries next sweep', () async {
    final t = DateTime.now();
    final id = await _seed(
      createdAt: t,
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    sender.fail = true;
    await rx.sweepOnceForTest(now: t);
    final row = await outbox.findByMsgId(id);
    expect(row!.attempt, 1);
    expect(row.nextRetryAt.isAfter(t), isTrue);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/outbox_retransmitter_test.dart
```

Expected: build errors / classes missing.

- [ ] **Step 3: Implement the retransmitter**

Create `lib/chat/outbox_retransmitter.dart`:

```dart
import 'dart:async';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/outbox_dao.dart';

/// Indirection so tests can intercept the actual send.
abstract class RetransmitSender {
  Future<void> sendOnce(String peer, List<int> envelopeBytes);
}

class OutboxRetransmitter {
  OutboxRetransmitter({
    required this.outbox,
    required this.chats,
    required this.sender,
  });

  final OutboxDao outbox;
  final ChatsDao chats;
  final RetransmitSender sender;
  Timer? _sweepTimer;

  static const sweepInterval = Duration(seconds: 10);
  static const maxAge = Duration(hours: 24);

  /// Ladder per spec §7g — 30s / 60s / 5m / 30m / 1h / 1h …
  /// `attempt` is the post-bump attempt count (1-based: the value we'll
  /// write into the row after the retry just happened).
  static DateTime nextRetryAt({required int attempt, required DateTime now}) {
    const ladder = <Duration>[
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(minutes: 5),
      Duration(minutes: 30),
      Duration(hours: 1),
    ];
    final idx = (attempt - 1).clamp(0, ladder.length - 1);
    return now.add(ladder[idx]);
  }

  void start() {
    _sweepTimer ??= Timer.periodic(sweepInterval, (_) => _sweep());
  }

  void stop() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  /// Synchronous, test-friendly entry. Production `_sweep` is the same body
  /// but takes `DateTime.now()` and ignores its return value.
  Future<void> sweepOnceForTest({required DateTime now}) => _sweepAt(now);

  Future<void> _sweep() => _sweepAt(DateTime.now());

  Future<void> _sweepAt(DateTime now) async {
    final due = await outbox.dueBefore(now);
    for (final row in due) {
      // 24h expiry — drop the row, mark the message failed, surface in UI.
      if (now.difference(row.createdAt) > maxAge) {
        await chats.updateDeliveryState(row.msgId, DeliveryState.failed);
        await outbox.delete(row.msgId);
        // ignore: avoid_print
        print('[OR] expired msgId=${row.msgId} attempt=${row.attempt}');
        continue;
      }
      try {
        await sender.sendOnce(row.peerPubkeyHex, row.envelopeBytes);
        // ignore: avoid_print
        print('[OR] retransmit msgId=${row.msgId} attempt=${row.attempt + 1}');
      } catch (e) {
        // ignore: avoid_print
        print('[OR] retransmit_fail msgId=${row.msgId} err=$e');
      }
      // Whether send succeeded or threw, bump attempt + nextRetryAt. The
      // receipt path is what deletes the row on success; without a receipt
      // we keep retrying with backoff.
      final newAttempt = row.attempt + 1;
      await outbox.bumpAttempt(
          row.msgId, nextRetryAt(attempt: newAttempt, now: now));
    }
  }
}
```

- [ ] **Step 4: Run tests**

```powershell
flutter test test/chat/outbox_retransmitter_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/outbox_retransmitter.dart `
        test/chat/outbox_retransmitter_test.dart
git commit -m "retransmitter: 10s sweep, ladder backoff, 24h expiry"
```

---

## Task 12: Wire debouncer + retransmitter into `MessageService` + provider

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `lib/chat/chat_providers.dart`
- Modify: `lib/features/chat/message_service_provider.dart`

- [ ] **Step 1: Add `_MessageServiceReceiptSender` + `_MessageServiceRetransmitSender` adapters**

These adapters live in `lib/chat/message_service.dart` (private classes near EOF) so they can call into `_encryptAndSend` and `_currentDisplayName` without exposing them publicly:

```dart
class _MessageServiceReceiptSender implements ReceiptSender {
  _MessageServiceReceiptSender(this._svc);
  final MessageService _svc;
  @override
  Future<String?> currentDisplayName() => _svc._currentDisplayName();
  @override
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes) =>
      _svc._encryptAndSend(peer, envelopeBytes);
}

class _MessageServiceRetransmitSender implements RetransmitSender {
  _MessageServiceRetransmitSender(this._svc);
  final MessageService _svc;
  @override
  Future<void> sendOnce(String peer, List<int> envelopeBytes) =>
      _svc._encryptAndSend(peer, envelopeBytes);
}
```

Add the `late` field for the retransmitter on `MessageService`:

```dart
late final OutboxRetransmitter retransmitter;
```

Add a helper called by the provider:

```dart
/// Constructs and assigns the receipt debouncer + outbox retransmitter
/// after the MessageService is built. Two-step wiring because both
/// helpers need a `this` reference, which a constructor can't supply.
void attachLayerB() {
  receiptDebouncer = DeliveryReceiptDebouncer(
      _MessageServiceReceiptSender(this));
  retransmitter = OutboxRetransmitter(
    outbox: outboxDao,
    chats: dao,
    sender: _MessageServiceRetransmitSender(this),
  );
  retransmitter.start();
}
```

Add to `dispose()`:

```dart
Future<void> dispose() async {
  retransmitter.stop();
  receiptDebouncer.dispose();
  await _sub.cancel();
}
```

Imports to add at top:

```dart
import 'outbox_retransmitter.dart';
```

- [ ] **Step 2: Add `outboxDaoProvider` in `chat_providers.dart`**

In `lib/chat/chat_providers.dart`, mirror the existing `peerBundleStateDaoProvider` / `chatsDaoProvider` pattern:

```dart
final outboxDaoProvider = Provider<OutboxDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OutboxDao(db);
});
```

Add the import: `import '../data/outbox_dao.dart';`

- [ ] **Step 3: Wire into `messageServiceProvider`**

In `lib/features/chat/message_service_provider.dart`:

```dart
final messageServiceProvider = FutureProvider<MessageService>((ref) async {
  final identity = await ref.watch(identityProvider.future);
  final crypto = await ref.watch(cryptoServiceProvider.future);
  final relay = await ref.watch(relayClientProvider.future);
  final dao = ref.watch(chatsDaoProvider);
  final peerBundleDao = ref.watch(peerBundleStateDaoProvider);
  final outboxDao = ref.watch(outboxDaoProvider);                  // NEW
  final wake = ref.watch(wakeClientProvider);
  final groupMembersDao = ref.watch(groupMembersDaoProvider);
  final groupOpsLogDao = ref.watch(groupOpsLogDaoProvider);
  final signing = ref.watch(signingServiceProvider);
  final contactsRepository = ref.watch(contactsRepositoryProvider);
  final profileDao = ref.watch(profileDaoProvider);
  final svc = MessageService(
    crypto: crypto,
    relay: relay,
    dao: dao,
    peerBundleDao: peerBundleDao,
    outboxDao: outboxDao,                                          // NEW
    myPubkeyHex: identity.publicKeyHex,
    wake: wake,
    groupMembersDao: groupMembersDao,
    groupOpsLogDao: groupOpsLogDao,
    signing: signing,
    contactsRepository: contactsRepository,
    profileDao: profileDao,
  );
  svc.attachLayerB();                                              // NEW
  ref.onDispose(() => svc.dispose());
  return svc;
});
```

- [ ] **Step 4: Verify the full app boots**

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Expected: analyze warnings only baseline-info, all tests PASS, debug APK builds. The retransmitter timer will be running in any device-launch but with no outbox rows nothing happens.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/message_service.dart lib/chat/chat_providers.dart `
        lib/features/chat/message_service_provider.dart
git commit -m "wire: attach DeliveryReceiptDebouncer + OutboxRetransmitter"
```

---

## Task 13: `MessageBubble` — tick rendering + tap-to-retry

**Files:**
- Modify: `lib/features/chat/message_bubble.dart`

- [ ] **Step 1: Extend the widget API**

Update the constructor signature:

```dart
const MessageBubble({
  super.key,
  required this.body,
  required this.fromMe,
  required this.timestamp,
  this.senderLabel,
  this.deliveryState,        // NEW — null for inbound bubbles
  this.onRetryTap,           // NEW — called only when deliveryState == failed
});

final String body;
final bool fromMe;
final DateTime timestamp;
final String? senderLabel;
final DeliveryState? deliveryState;
final VoidCallback? onRetryTap;
```

Add the import: `import '../../data/app_database.dart';`

- [ ] **Step 2: Render the tick on outbound bubbles**

Inside the inner `Column` that holds body + timestamp, after the timestamp `Text(...)`, add:

```dart
if (fromMe && deliveryState != null)
  Padding(
    padding: const EdgeInsets.only(top: 2),
    child: _TickIcon(state: deliveryState!, onRetryTap: onRetryTap),
  ),
```

Add a private widget at the end of the file:

```dart
class _TickIcon extends StatelessWidget {
  const _TickIcon({required this.state, this.onRetryTap});
  final DeliveryState state;
  final VoidCallback? onRetryTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    switch (state) {
      case DeliveryState.sent:
        return Icon(Icons.check, size: 12, color: muted);
      case DeliveryState.delivered:
        return Icon(Icons.done_all, size: 12, color: muted);
      case DeliveryState.read:
        return Icon(Icons.done_all, size: 12, color: AppColors.accent);
      case DeliveryState.failed:
        return GestureDetector(
          onTap: onRetryTap,
          child: Tooltip(
            message: 'Tap to retry',
            child: Icon(Icons.error_outline,
                size: 12, color: Theme.of(context).colorScheme.error),
          ),
        );
    }
  }
}
```

- [ ] **Step 3: Manual rendering sanity check**

Existing bubble tests don't cover icons (the file has no test file today). Add one minimal widget test at `test/features/chat/message_bubble_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/features/chat/message_bubble.dart';

void main() {
  testWidgets('outbound bubble renders single check for sent state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.sent,
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('outbound read bubble renders double check', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read,
        ),
      ),
    ));
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('outbound failed bubble shows error + tap calls callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: true,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.failed,
          onRetryTap: () => taps++,
        ),
      ),
    ));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.error_outline));
    expect(taps, 1);
  });

  testWidgets('inbound bubble never renders a tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          body: 'hi', fromMe: false,
          timestamp: DateTime.now(),
          deliveryState: DeliveryState.read, // ignored when fromMe == false
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
```

```powershell
flutter test test/features/chat/message_bubble_test.dart
```

Expected: 4 PASS.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/chat/message_bubble.dart `
        test/features/chat/message_bubble_test.dart
git commit -m "bubble: render delivery ticks with tap-to-retry on failed"
```

---

## Task 14: `ChatThreadScreen` — pass `deliveryState`, fire read receipts on visibility

**Files:**
- Modify: `lib/features/chat/chat_thread_screen.dart`
- Modify: `lib/features/chat/chat_thread_provider.dart` if separate (or inline if not)

This task wires the existing `ChatThreadScreen` to (a) feed `deliveryState` into each outbound bubble's `MessageBubble`, (b) plumb a `onRetryTap` that re-enqueues the row via the retransmitter, (c) call `markRead` + `enqueueRead` when the screen becomes visible (initial build + lifecycle resume + scrolled-to-bottom check).

Because this file is UI-heavy with a lot of existing structure (335 LOC), the steps below are guided edits rather than a full rewrite. Read the file before starting so you know the current layout.

- [ ] **Step 1: Add a `_markReadIfFocused` helper to the State class**

Inside the `_ChatThreadScreenState` class (it must use `WidgetsBindingObserver` — add the mixin and `WidgetsBinding.instance.addObserver(this)` / `removeObserver(this)` in `initState` / `dispose` if not already there):

```dart
Future<void> _markReadIfFocused() async {
  // Direct chats only — group bubbles don't have receipts in this phase.
  if (widget.chatKind != 'direct') return;
  final svc = await ref.read(messageServiceProvider.future);
  final unread = await svc.dao.unreadInboundMsgIds(widget.peerPubkeyHex);
  if (unread.isEmpty) return;
  await svc.dao.markRead(unread);
  svc.receiptDebouncer.enqueueRead(
      peer: widget.peerPubkeyHex, msgIds: unread);
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) _markReadIfFocused();
}
```

Call `_markReadIfFocused()` once at the end of `initState` (after the first frame using `WidgetsBinding.instance.addPostFrameCallback`).

- [ ] **Step 2: Pass `deliveryState` + `onRetryTap` to outbound bubbles**

Inside the message-list `ListView.builder` (or whichever iteration renders `MessageBubble`), for every outbound message wrap the bubble in a `StreamBuilder` so live tick changes re-render:

```dart
return StreamBuilder<DeliveryState>(
  stream: svc.dao.watchDeliveryState(msg.id),
  initialData: msg.deliveryState,
  builder: (context, snap) {
    final state = snap.data ?? DeliveryState.sent;
    return MessageBubble(
      body: msg.body,
      fromMe: true,
      timestamp: msg.sentAt,
      deliveryState: state,
      onRetryTap: state == DeliveryState.failed
          ? () => _retrySend(msg.id)
          : null,
    );
  },
);
```

For inbound bubbles, leave `deliveryState` unset (null) and don't wrap in StreamBuilder — they don't have a tick.

- [ ] **Step 3: Implement `_retrySend`**

```dart
Future<void> _retrySend(String msgId) async {
  final svc = await ref.read(messageServiceProvider.future);
  final msg = await svc.dao.findMessageById(msgId);
  if (msg == null) return;
  // Re-build the inner envelope from the message body (we don't keep the
  // original encoded bytes; rebuilding gives a fresh canonical msgId-less
  // form except for msgId itself, which stays the same — that's what the
  // recipient dedups on).
  final myName = await svc._currentDisplayName();
  final lamport = msg.lamport;
  final jsonBytes = InnerEnvelope.buildText(
    chatId: svc.myPubkeyHex,
    lamport: lamport,
    body: msg.body,
    senderDisplayName: myName,
    msgId: msgId,
  );
  // Re-insert outbox row with attempt=0 + immediate nextRetryAt so the
  // sweeper picks it up on its next pass (within ~10s).
  final now = DateTime.now();
  await svc.outboxDao.insert(
    msgId: msgId, peerPubkeyHex: widget.peerPubkeyHex,
    envelopeBytes: jsonBytes,
    createdAt: now, nextRetryAt: now,
  );
  // Reset the tick to `sent` so the user gets feedback immediately.
  await svc.dao.advanceDeliveryStateIfHigher(msgId, DeliveryState.sent);
}
```

> **Visibility note:** `_currentDisplayName` is private on `MessageService`. Either (a) expose it as `Future<String?> currentDisplayName()` (preferred — small leak, used by debouncer too), or (b) duplicate the `profileDao.get()?.displayName` lookup here. Choose (a). Update `MessageService` to have a public `Future<String?> currentDisplayName()` that delegates to `_currentDisplayName`. Update the `_MessageServiceReceiptSender` adapter from Task 12 to call the public version.

- [ ] **Step 4: Manual verification — quick widget run**

There's no automated test for ChatThreadScreen behavior in the existing suite (it's covered by manual two-phone E2E). Run:

```powershell
flutter analyze lib/features/chat/chat_thread_screen.dart
flutter test
```

Expected: analyze clean, all tests still pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/message_service.dart lib/features/chat/chat_thread_screen.dart
git commit -m "chat_thread: pass deliveryState to bubbles + fire read receipts"
```

---

## Task 15: `forgetPeer` cascades `outboxDao.markPeerFailed`

**Files:**
- Modify: `lib/chat/message_service.dart`
- Modify: `test/chat/message_service_test.dart`

Per spec §7o, deleting + re-pairing a contact must drop any outstanding outbox rows for that peer — otherwise the retransmitter will burn cycles encrypting against a session that no longer exists, eventually failing every row to `failed`.

- [ ] **Step 1: Write failing test**

Append to `test/chat/message_service_test.dart`:

```dart
test('forgetPeer drops the peer\'s outbox rows', () async {
  await svc.sendText(peerPubkeyHex: 'peerA', body: 'a');
  await svc.sendText(peerPubkeyHex: 'peerB', body: 'b');
  final preA = await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)));
  expect(preA.where((r) => r.peerPubkeyHex == 'peerA'), isNotEmpty);

  await svc.forgetPeer('peerA');

  final postA = await svc.outboxDao.dueBefore(
      DateTime.now().add(const Duration(days: 1)));
  expect(postA.where((r) => r.peerPubkeyHex == 'peerA'), isEmpty);
  expect(postA.where((r) => r.peerPubkeyHex == 'peerB'), isNotEmpty);
});
```

- [ ] **Step 2: Run to confirm failure**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: the new test fails — outbox rows still present after forgetPeer.

- [ ] **Step 3: Patch `forgetPeer`**

In `lib/chat/message_service.dart`, update `forgetPeer`:

```dart
Future<void> forgetPeer(String peerPubkeyHex) async {
  _pendingByPeer.remove(peerPubkeyHex);
  await outboxDao.markPeerFailed(peerPubkeyHex);   // NEW
  await peerBundleDao.deleteByPubkey(peerPubkeyHex);
  await crypto.forgetPeer(peerPubkeyHex);
  _log('forgetPeer cleared bundle+session+outbox for ${_short(peerPubkeyHex)}');
}
```

- [ ] **Step 4: Run tests**

```powershell
flutter test test/chat/message_service_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/chat/message_service.dart test/chat/message_service_test.dart
git commit -m "message_service: forgetPeer cascades outbox cleanup"
```

---

## Task 16: Quality gates — `flutter analyze` + `flutter test` + APK build

**Files:**
- None (verification only).

- [ ] **Step 1: Full analyze pass**

```powershell
flutter analyze
```

Expected: only the existing baseline info-level messages. No new warnings introduced. If any: fix in this task's commit.

- [ ] **Step 2: Full test pass**

```powershell
flutter test
```

Expected: ≥ existing test count (208 + ~12 new = ~220 passing + 2 existing skips + 1 new migration skip).

- [ ] **Step 3: Debug APK**

```powershell
flutter build apk --debug
```

Expected: build succeeds.

- [ ] **Step 4: Commit if any cleanup was needed**

If steps 1–3 surface any drift / minor fixes, commit them now:

```powershell
git add -A
git commit -m "quality: address analyzer + test drift surfaced by 10.4.3b"
```

If everything was already clean, skip the commit.

---

## Task 17: Two-phone live E2E verify against the live relay

**Files:**
- None (manual verification + log capture).

Run these on two real devices both connected to the same live relay at `ws://34.42.231.29:8080/v1/signal`. Builds for each device should be the same APK from Task 16. Document results in `heart-beat-v3/docs/testing-session-results-2026-05-26-10.4.3b.md` so future debugging has a baseline.

- [ ] **F1: Fresh install over v6 — migration smoke test**

Sideload the new APK over a device that has the v6 (10.4.2 / 10.4.3a-pre) install. Open the app. Existing chats and contacts must persist. New messages sent now should show the single-check tick within ~1s.

- [ ] **F2: Happy-path delivered + read tick**

A: send "hello" to B. A's bubble should show single check ✓ → double check ✓✓ within a few seconds (B's `delivered` receipt) → double check (accent color) ✓✓ when B opens the chat (`read`). B's bubble (inbound) shows no tick.

- [ ] **F3: Recipient offline (Issue #2 closed — Layer A flush + Layer B tick)**

`adb shell am force-stop com.sahitkogs.heartbeat` on B. A sends "while-offline". A's bubble: ✓ within seconds (sent), stays at ✓ until B relaunches. B opens app → A's bubble flips to ✓✓ (delivered) within a few seconds, then ✓✓-accent (read) once B's UI renders the message.

- [ ] **F4: Sender retransmit on half-dead WS (Issue #1 closed)**

Hard-to-stage manually. Acceptable alternative: artificially make A's WS think it's connected but actually dead (e.g. `adb shell svc wifi disable` mid-send), send, re-enable wifi. Within ~30 s the retransmitter sweeps, re-sends; ✓✓ arrives.

- [ ] **F5: 24h expiry → failed tick → tap-to-retry**

Hard to stage in a single session. Validate the code path instead: in `OutboxRetransmitter.maxAge`, temporarily change `24` to `1` (one minute) for a single test run, send to a permanently-offline peer, wait ~70 s, observe the bubble flip to ⚠. Tap the icon, observe it flips back to ✓ and starts retrying. **Revert the constant change before committing anything else.**

- [ ] **F6: Contact delete cascade**

Delete a contact who has un-acked outbox rows. After delete, the retransmitter must stop touching that peer. Inspect via `adb logcat | grep '\[OR\]'` — no `retransmit_fail msgId=...` for that peer post-delete.

- [ ] **Step 7: Capture results**

Write `heart-beat-v3/docs/testing-session-results-2026-05-26-10.4.3b.md` summarizing PASS/FAIL per scenario. Commit:

```powershell
git add docs/testing-session-results-2026-05-26-10.4.3b.md
git commit -m "docs: 10.4.3b two-phone E2E results"
```

---

## Task 18: Tag + Play Store internal upload

- [ ] **Step 1: Bump version**

In `pubspec.yaml`:

```yaml
version: 1.0.3+4
```

(Or whichever is the next available Play `versionCode`. Confirm against Play Console before committing.)

- [ ] **Step 2: Build release APK + AAB**

```powershell
flutter build apk --release
flutter build appbundle --release
```

Expected: both succeed.

- [ ] **Step 3: Local tag**

```powershell
git add pubspec.yaml
git commit -m "release: 1.0.3+4 — phase 10.4.3b (client receipts + outbox)"
git tag -a v1.0.3-phase10.4.3b -m "Phase 10.4.3b — client receipts + outbox + tick UI"
```

- [ ] **Step 4: PAUSE — user pushes + uploads**

Do **not** push to GitHub or upload to Play Store from this session. The user handles:

```powershell
git push origin main --tags
# then: upload build/app/outputs/bundle/release/app-release.aab to Play Console
# Internal Testing track, release notes:
#   "Phase 10.4.3b — delivery receipts (sent / delivered / read ticks),
#    persistent outbox with retransmit, dedup. Pairs with server 0.2.0-offline-queue."
```

- [ ] **Step 5: Live verification post-deploy**

After user installs the new release on at least one test device, confirm tick state changes round-trip with another device still running the previous version (Layer B fallback per spec §10) — the old peer should keep receiving messages normally; only the new ↔ new pair gets ticks.

---

## Plan Self-Review

**Spec coverage:**

| Spec section | Implemented in |
|---|---|
| §5a msgId added to text | Tasks 4, 6 |
| §5b new delivery_receipt envelope | Tasks 5, 8 |
| §5d InnerEnvelope.parse sixth branch | Task 5 |
| §7a Drift schema additions (deliveryState + outbox) | Tasks 1, 3 |
| §7b InnerEnvelope changes + backwards-compat read | Tasks 4, 5 |
| §7c sendText changes (msgId + outbox row pre-send) | Task 6 |
| §7d Inbound text dedup + receipt enqueue | Task 7 |
| §7e Inbound receipt with monotonic guard + spoof guard | Task 8 |
| §7f DeliveryReceiptDebouncer (250 ms) | Task 10 |
| §7g OutboxRetransmitter (10s sweep, ladder, 24h expiry) | Task 11 |
| §7h Chat UI tick rendering + tap-to-retry | Tasks 13, 14 |
| §7i Read-receipt trigger on visibility | Task 14 |
| §7j outbox_dao.dart | Task 2 |
| §7k Lifecycle wiring | Task 12 |
| §7m Drop _unackedByPeer + unconditional wake | Task 9 |
| §7n Test surface (outbox_dao, message_service, debouncer) | Tasks 2, 6–11, 13 |
| §7o forgetPeer + markPeerFailed cascade | Task 15 |
| §10 Rollout (backwards-compat parse + state-machine fallback) | Task 4 (parse), Task 17 (cross-version test) |

**Backwards-compat checks:**

- Old peer sends text without msgId → Task 4's parse generates a UUID locally. No dedup possible across that peer's retransmits but no message loss.
- Old peer receives `delivery_receipt` → falls into `unhandled_inner_type` branch in their `_handleDeliver` (pre-Phase-2 has only 5 known kinds), logs + drops. No crash.

**Placeholder scan:** No TBDs. Every step has the actual code or commands. The two places that originally looked placeholder-shaped (the `bumpAttempt` double-read inside `Value(...)` in Task 2 — flagged with a "use this version" note; and the F4/F5 manual-staging instructions in Task 17 — given alternatives) have explicit guidance.

**Type consistency:**

- `OutboxData` (Drift generated) used in Tasks 2, 11, 14. `Outbox` table referenced in Tasks 1, 2 with same column shape (`msgId`/`peerPubkeyHex`/`envelopeBytes`/`attempt`/`nextRetryAt`/`createdAt`).
- `DeliveryState` enum ordering `{sent, delivered, read, failed}` used identically in Tasks 1, 3, 8, 11, 13. The "monotonic" assumption in Task 3's `advanceDeliveryStateIfHigher` (`sent` < `delivered` < `read` by ordinal index) holds for the first three; `failed` is intentionally a side-state (Task 11 uses the un-guarded `updateDeliveryState` for that transition).
- `ReceiptKind` enum `{delivered, read}` used in Tasks 5, 8, 10.
- `MessageService.outboxDao` field added in Task 6, consumed in Tasks 7–11, 14, 15.
- `MessageService.receiptDebouncer` (late) declared in Task 7, assigned in Task 12, consumed in Tasks 7, 14.
- `MessageService.retransmitter` (late) declared in Task 12, started/stopped via `attachLayerB` / `dispose`.

If anything in the actual implementation drifts from these names (e.g. Drift's generated `OutboxData` vs `Outbox` row class) adjust call sites at the time of implementation — the test code in this plan uses the names that Drift generates by convention (`<Table>Data`).
