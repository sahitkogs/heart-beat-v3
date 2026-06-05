# Heart.Beat v3 — 3-Emulator Reliability Campaign: Results

> **Run:** 2026-06-01. **Build under test:** debug APK at commit `278bee5` (Phases A–D: server `0.3.0-presence` live + client presence/reliability/diagnostics). **Method:** adb orchestration + client/server log correlation. **Catalog:** `docs/2026-06-01-emulator-e2e-test-plan.md`.
> **Scope this session:** the **core reliability slice on two stable devices** (alice↔carol). The host could not keep three x86 emulators alive simultaneously (Heartbeat2 crashed repeatedly), so the 3-device group family and the full delivery matrix were deferred — see "Not run" below. **No fixes applied this session (log-only).**

## Device map

| Device | AVD | serial | identity (pubkey) | name |
|---|---|---|---|---|
| Dev1 | Heartbeat | emulator-5554 | `116d49ed…e8c19b` | alice |
| Dev3 | Heartbeat3 | emulator-5558 | `5b5387f9…1274f5` | carol |
| Dev2 | Heartbeat2 | emulator-5556 | — | bob (AVD unstable — excluded) |

All `android-36 / google_apis_playstore` (FCM-capable). Relay `0.3.0-presence` @ `34.42.231.29:8080`.

## Summary

| | |
|---|---|
| Cases executed | 7 (of 30 cataloged) |
| **PASS** | 5 |
| **PARTIAL / observation** | 2 |
| **FAIL (lost message / lost record)** | **0** |
| CRITICAL findings | 0 |
| HIGH findings | 0 |
| MEDIUM findings | 1 (presence-flush not isolated — see F3) |

**Headline:** Every message sent in this run was delivered and persisted; no record was lost. The deployed presence server + client green-tick + outbox reliability all functioned live. One MEDIUM observation: the *presence-triggered* flush could not be isolated in the live timing (the pre-existing outbox retransmitter delivered first) — the message was never at risk, but the new feature's specific contribution wasn't demonstrated end-to-end live (it is covered by unit + integration tests).

---

## Results by case

### ✅ 0.1–0.2 Onboarding + pairing — PASS
Fresh installs onboarded (alice/carol), FCM-registered, paired bidirectionally via paste-hex (nickname + 64-char hex). Profile screen shows QR + full hex + "Copy hex"; **Diagnostics entry present** (D2). Evidence: profile screenshots; pubkeys matched logcat-unique hex.

### ✅ 0.3 / 1.1 Baseline 1:1 delivery (foreground) — PASS
alice→carol "baseline-A1-hello-carol" (23 bytes).
- alice: `[MS] encrypted+sent peer=5b5387… msgId=e776f3…42a13a` → `[MS] receipt_applied msgId=e776f3… kind=delivered from=carol`.
- carol: `[MS] inbound MESSAGE from=116d49… ctBytes=357` → `[MS] decrypted … bodyLen=23` → returned receipt.
Bundle exchange (libsignal bootstrap) completed on first open. Delivered + delivery-receipt round-trip confirmed both sides.

### ✅ 2.1 Presence badge (online) — PASS  *(validates the whole Phase A+B chain live)*
- alice's contacts/thread show **green dot** next to "carol" + header **"online"**; carol's show green + "online" for alice. **Bidirectional**.
- This proves: deployed `/v1/presence` (signed) → `PresenceClient` parse → poller → 3-state badge, all live. The wire contract matches (no 401, badge painted within a poll).

### ✅ 3.1 + 3.2 Stranded message delivered on peer return — PASS (central goal met)
1. carol force-stopped (offline + FCM suppressed). alice sends "flush-test-stranded" (19 bytes).
   - alice: `encrypted+sent msgId=4210f1…a7f455` → `[Relay] ErrorFrame` (recipient_offline) → `wake_dispatching`/`wake_dispatched` (wake can't land — carol stopped). Message sits in alice's outbox.
2. carol relaunched → WS reconnects (cold-start ~70s under load).
   - alice: `[OR] retransmit kind=text msgId=4210f1… attempt=1` (+30s), `attempt=2` (+~70s) → `[MS] receipt_applied msgId=4210f1… kind=delivered`.
   - carol: received + `decrypted`. **Delivered with no manual resend.**

### ✅ 3.3 Exactly-once under duplicate inbound — PASS
carol's log shows the stranded message arrive **twice** (`inbound MESSAGE … ctBytes=276` ×2 at 12:29:11) but **only one bubble renders** in carol's UI → `msgId` dedup holds. No duplicate shown.

### ⚠️ F3 (MEDIUM) — presence-triggered flush not isolated
`[OR] flush_for_peer` **never logged**, and no `[Presence]`-error lines (PresenceClient only logs on error, so success is silent — badge updates confirm the poll succeeded). The stranded message was delivered by the **pre-existing outbox retransmitter ladder** (`attempt=1/2`), not the new presence-flush.
- **Root-cause hypothesis:** carol's cold-start reconnect (~70s) aligned with the retransmitter's 60s ladder rung, so the retransmitter delivered the message *before* alice's 25s poller observed carol's stale→online transition. By the time the poller would have fired `flushForPeer`, the outbox row was already drained → `kickPeer` matched 0 rows → early return (no log).
- **Impact:** none on reliability — the message was delivered and never at risk; the presence-flush is a *latency optimization* over the ladder, redundant here. The flush mechanism itself is verified by unit tests (C1/C2/C3) and the integration test (`pollOnce`→`flushForPeer`).
- **To demonstrate its added value live (follow-up):** strand a message until the outbox is deep in backoff (≥30 min rung), THEN bring the peer online — the flush should deliver immediately instead of waiting for the next rung. Impractical to set up in a short live session.

### ✅ 5.1 (partial) Persistence across force-stop — PASS
carol was `am force-stop`-ed and relaunched during F3; her earlier inbound "baseline-A1-hello-carol" (12:24) **survived** and rendered after relaunch alongside the new message. Identity + libsignal session persisted (no re-bootstrap; `bundle already sent`). Full both-device force-stop+relaunch sweep deferred.

### ✅ 6.1 Records-integrity (Diagnostics) — PASS  *(validates Phase D live)*
alice → My Profile → Diagnostics: **Stuck outbox 0**, **Orphaned sent 0**, "All records accounted for", **Re-kick disabled** (no stuck peers). Confirms the integrity query runs and — crucially — **orphaned-sent is not inflated** despite alice having sent messages (the `known_ticks` gate works; receipts cleared them).

---

## Not run this session (deferred follow-ups)
- **Family 1.2–1.6** full delivery matrix (backgrounded / swipe-killed natural FCM wake / emulator-offline-then-online / server offline-queue replay).
- **Family 4** 3-member groups (create/add/remove/leave/offline-member) — needs the 3rd device; Heartbeat2 AVD is unstable on this host.
- **Family 2.2–2.4** presence transition green→amber→grey + background-poller-stops verification.
- **Family 7** chaos (mid-send network drop, rapid flap, both-offline).

**Recommendation:** run the deferred families either on **physical devices** (more stable than 3 concurrent x86 emulators) or by **recreating Heartbeat2** / running 2-at-a-time. The natural-FCM-wake cases (1.4) specifically need a non-force-stop kill (swipe-from-recents).

## Follow-up tasks (each is non-blocking; nothing lost)
1. **(MEDIUM)** Live-demonstrate the presence-flush adding value (deep-backoff strand → peer returns → immediate flush). Optionally add a one-line `[OR] flush_for_peer … kicked=0` log even on the no-op path to make the poller's flush attempts observable in logs.
2. **(LOW)** Re-run the full delivery matrix + 3-device groups on stable hardware.
3. Carry the deferred server hardening (`TouchLastSeen` timeout context — see `presence-server-followup` memory) into the next server redeploy.
