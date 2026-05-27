# Phase 10.4.3b — Two-emulator E2E results

**Date:** 2026-05-27
**Build under test:** main @ `b7bfc3c` (chat_thread receipt race fix) after Tasks 1–15 of `docs/2026-05-26-client-receipts-implementation-plan.md`.
**Verification rig:** Android emulators `Heartbeat` (5554) and `Heartbeat2` (5556), both `google_apis_playstore` x86_64 / android-36. Driven via two `danielealbano/android-remote-control-mcp` v1.7.0 instances exposed to Claude Code as `android-alice` (5554) and `android-bob` (5556).
**Live relay:** `ws://34.42.231.29:8080/v1/signal` with Phase 10.4.3a offline queue.
**Unit test baseline:** `flutter test` = 247 ✅ / 3 skipped after the receipt-fallback regression fix added two new tests.

## Scenarios

### F1 — Migration v6 → v7 — **PASS**

Installed `v6.apk` (built from main @ `53d4dd6`) on Alice. Set display name `Alice`, allowed notifications. Installed v6.apk on Bob, set up `Bob`, paired both ways via paste-hex. Bob sent `hi v6` → Alice received and decrypted (`bodyLen=5`). Upgraded both to v7.apk in-place. After relaunch, Alice's chat list showed `B Bob hi v6 14:16` — chat row, messages, and contacts all preserved. Alice then sent `hello v7`; Bob received and emitted a delivered receipt; Alice's bubble immediately rendered the muted double-check (✓✓ delivered). Drift's additive v6→v7 migration is non-destructive on live data.

### F2 — Happy-path sent → delivered → read tick — **PASS (after 2 regressions fixed)**

Two regressions surfaced and were fixed in-session:

1. **`_handleDeliveryReceipt` dropped follow-up receipts.** When the delivered receipt drained the outbox row, a subsequent read receipt for the same msgId short-circuited at `receipt_no_outbox` and never reached the state-advance, so Alice's tick stayed at `delivered`. Fixed in `8db9b2d` — when the outbox row is gone, fall back to `messages.chatId == frame.fromPubkeyHex` for spoof verification, then advance state. Two new tests pin the regression: `read after delivered advances tick (outbox already drained)` and `receipt from wrong peer with no outbox row is ignored`.
2. **`_markReadIfFocused` raced `chatProvider`.** It used `ref.read(chatProvider(...)).valueOrNull`, but `chatProvider` is a `StreamProvider`. On the first `addPostFrameCallback` the stream hadn't emitted yet, so `valueOrNull` was `null` and the chat-kind guard short-circuited before any read receipt could fire. Fixed in `b7bfc3c` — calls `svc.dao.getChat(chatId)` directly which awaits the row read.

After both fixes: Alice sent `f2 take3`, Bob received + emitted delivered, Bob then opened the chat and `_markReadIfFocused` fired, sending a batched read receipt covering both `f2 retry` and `f2 take3`. Alice's logs:
```
[MS] receipt_applied msgId=30ab59…ca4062 kind=delivered
[MS] receipt_applied_no_outbox msgId=d40a99…7d2613 kind=read
[MS] receipt_applied_no_outbox msgId=30ab59…ca4062 kind=read
```
Both bubbles transitioned ✓ → ✓✓ → ✓✓ (accent).

### F3 — Recipient offline + FCM wake — **PASS (with caveat)**

Alice force-stopped (`adb shell am force-stop`). Bob sent `while offline`. Bob's logs showed the unconditional wake firing:
```
[MS] wake_dispatching peer=78d428…c49156 (unconditional)
[MS] wake_dispatched peer=78d428…c49156
```
Alice cold-launched ~80s later. The relay's Layer A queue immediately flushed two copies of the envelope (Layer A keeps re-queueing while peer is offline; libsignal rejected the duplicate via `DuplicateMessageException` — expected safety net). The remaining copy decrypted cleanly:
```
[MS] decrypted from=b50021…b385fd chat=b50021…b385fd bodyLen=13
[Relay] sent to=b500210d envBytes=309   // delivered receipt back to Bob
```

**Caveat:** I could not directly observe an FCM push landing on Alice's emulator — `adb logcat -s FCM:* FlutterFire*:*` produced no incoming-message lines on the recipient. The server-side `wake_dispatched` confirms the relay invoked FCM via `wakeOfflineRecipient`, but actual FCM delivery to emulators (even with Play Services) is known to be unreliable. The delivery itself still worked via Layer A queue, which is the load-bearing path; the FCM wake is the supplementary nudge. A two-physical-phone follow-up is the only way to definitively validate FCM behavior end-to-end.

### F4 — Half-dead WS retransmit (Issue #1) — **PASS**

Disabled Bob's data + wifi (`adb shell svc data/wifi disable`). Bob sent `halfdead`. Logs:
```
[MS] sendText peer=78d428…c49156 bodyLen=8
[Relay] SEND while disconnected … kicking reconnect
[MS] ENCRYPT FAIL peer=78d428…c49156 err=Bad state: relay disconnected
```
Crucially, the encrypt failure was **logged and swallowed** (Phase 10.4.3b's new behaviour — the outbox row is the recovery handle). Re-enabled network ~30s later. First sweep at 14:35:46 was too early (relay still reconnecting) — logged `[OR] retransmit_fail`. Second sweep at 14:36:26 succeeded:
```
[OR] retransmit msgId=e4248531-3411-4179-9fd5-e2e63ffbd35a attempt=2
[Relay] inbound type=DeliverFrame raw=518B
[MS] receipt_applied msgId=e42485…fbd35a kind=delivered from=78d428…c49156
```
Full Issue #1 recovery loop closed.

### F5 — 24h expiry → failed tick → tap-to-retry — **PASS**

Temporarily set `OutboxRetransmitter.maxAge = Duration(minutes: 1)` (reverted before this commit). Force-stopped Alice (permanent-offline simulation). Bob sent `permaoffline`. Timeline:
```
14:39:12  sendText … encrypted+sent msgId=440c20… (initial)
14:39:42  [OR] retransmit … attempt=1            (first sweep ~30s)
14:40:12  [OR] expired msgId=440c20… attempt=1   (exactly 60s = maxAge)
```
At expiry the `permaoffline` bubble's accessibility row flipped to `clk` (clickable) — the only outbound bubble in the chat with that attribute. The `_TickIcon` wraps `Icons.error_outline` in a `GestureDetector` for the `failed` state and not for the other three states, which matches the accessibility-tree difference.

Tapping the failed icon at coordinates (990, 1530):
```
14:43:02  [OR] retransmit msgId=440c209c-… attempt=1   (new outbox row from _retrySend)
14:43:32  [OR] retransmit … attempt=2                  (ladder advance)
```
`_retrySend` re-inserted the outbox row with `nextRetryAt=now` and reset `delivery_state` to `sent`. The retransmitter immediately picked it up on the next sweep.

The constant has been reverted to `Duration(hours: 24)` before any commit that would ship.

### F6 — Contact delete stops retransmit — **PASS**

While `permaoffline` was still in `failed` state with active retransmit/wake activity for Alice's pubkey (last `[OR] retransmit … attempt=2` at 14:43:32), Bob deleted the Alice contact via the chat header bottom sheet → "Delete contact" → "Delete contact, chat, and history". Bob's log:
```
14:44:13  [MS] forgetPeer cleared bundle+session+outbox for 78d428…c49156
```
For 35+ seconds after that line, **no further `[OR]` activity for `440c209c` appeared.** The `outboxDao.markPeerFailed(peerPubkeyHex)` cascade dropped every outbox row keyed to Alice; the retransmitter's `dueBefore(now)` returned empty on subsequent sweeps. No spurious retries against a torn-down libsignal session.

## Summary

| Scenario | Result | Notes |
|---|---|---|
| F1 | PASS | Drift v6→v7 additive migration preserved chats, contacts, messages. |
| F2 | PASS | Two regressions fixed (commits `8db9b2d`, `b7bfc3c`). |
| F3 | PASS | Layer A delivery confirmed. FCM wake server-side dispatched; client-side FCM not directly observable on emulator. |
| F4 | PASS | Encrypt-fail swallow + retransmitter recovery on reconnect. |
| F5 | PASS | 24h expiry path (validated at 1-minute proxy), failed tick, tap-to-retry all functional. |
| F6 | PASS | `forgetPeer` cascade `outboxDao.markPeerFailed` halts retransmits. |

## Code changes during verification

Two follow-up commits beyond Tasks 1–15:

- `8db9b2d` — `message_service: receipt fallback when outbox row already drained`
- `b7bfc3c` — `chat_thread: _markReadIfFocused reads chat via DAO not StreamProvider`

Unit test count moved 245 → 247.

## Known limitations / follow-ups

- **FCM emulator opacity (F3):** verify on a physical phone before broad Play rollout.
- **Layer A duplicate flush (F3):** the relay re-pushed the same envelope twice on Alice's reconnect; libsignal's `DuplicateMessageException` rejected the second copy. Not a v3 bug — it's a Layer A queue semantics quirk worth tracking on the heartbeat-server side.
- **`DECRYPT FAIL DuplicateMessageException` after reinstall:** When Bob's app was reinstalled mid-session, the relay's offline queue delivered stale ciphertexts whose libsignal session counter was already advanced. Cosmetic log noise on reinstall flows; no data loss.
