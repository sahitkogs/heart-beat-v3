# Heart.Beat v3 — 3-Emulator Reliability Campaign: Test-Plan Catalog

> **Purpose:** Stress the full presence + reliability stack end-to-end on three Android emulators, covering the edge cases the central goal demands — *every message is sent, every record is kept*. Findings are **logged by severity (no fixes this session)** into the results doc.
> **Method:** adb orchestration + client/server log correlation (the multi-device + app-kill + FCM-wake scenarios cannot be done with in-process test runners — the runner dies with the app). Plan: `docs/2026-05-31-presence-reliability-plan.md` §Phase E. Spec: `docs/2026-05-31-presence-reliability-design.md`.

## Test bed

| Device | AVD | Port | adb serial | Role |
|---|---|---|---|---|
| **Dev1** | Heartbeat | 5554 | `emulator-5554` | A — primary / group creator |
| **Dev2** | Heartbeat2 | 5556 | `emulator-5556` | B — peer / invitee |
| **Dev3** | Heartbeat3 | 5558 | `emulator-5558` | C — third group member |

All three are `android-36 / google_apis_playstore / x86_64` → Google Play Services present → **FCM works**. App id `com.sahitkogs.heartbeat`. Relay live at `http://34.42.231.29:8080` (`0.3.0-presence`). Build under test: debug APK at `build/app/outputs/flutter-apk/app-debug.apk` (commit `278bee5`, all of Phases A–D).

### Orchestration cheatsheet
```bash
S1=emulator-5554; S2=emulator-5556; S3=emulator-5558; PKG=com.sahitkogs.heartbeat
adb -s $S1 install -r app-debug.apk                       # install (keeps data)
adb -s $S1 shell monkey -p $PKG -c android.intent.category.LAUNCHER 1   # launch
adb -s $S1 exec-out screencap -p > dev1.png               # screenshot (downsize to 600px before reading)
adb -s $S1 shell input tap <x> <y>                        # tap (coords from screenshot)
adb -s $S1 shell input text 'hello'                       # type
adb -s $S1 logcat -c                                      # clear log before a test
adb -s $S1 logcat -d -v time | grep -E 'flutter.*\[(MS|Relay|OR|Presence|BG)\]'   # client events
# server: gcloud compute ssh heartbeat-relay --project=heartbeat-app-prod --zone=us-central1-a \
#         --command='sudo docker logs -f --tail 40 heartbeat-relay'   # [ws]/[presence]/[wake]/[offline]
```

### Kill semantics (critical methodology note)
- **Natural kill** (what real users do) = **swipe from recents** or `adb shell am kill` — FCM data messages still wake the app. Use this for "killed-app delivery" cases.
- **`adb shell am force-stop`** puts the app in Android's *stopped* state, which **suppresses FCM until the user manually launches once**. Reserve it ONLY for the explicit "force-stop persistence" case, and expect server-side wake to fire while the client BG handler does not (that's the OS, not our bug).

### Severity scale (grade every finding against the central goal)
- **CRITICAL** — a message was not delivered, or a record was lost/corrupted.
- **HIGH** — delivered but wrong state (missing/incorrect tick, duplicate delivery, wrong order).
- **MEDIUM** — UX/timing (slow badge update, missing notification when app alive, etc.).
- **LOW** — cosmetic.

---

## Family 0 — Setup & baseline (gates everything else)

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 0.1 | Fresh install on all 3, launch each | Complete display-name onboarding: Dev1="alice", Dev2="bob", Dev3="carol" | Each lands on Chats home; no crash; FCM token registered (`[Phonebook] register ok` in logs) | All 3 onboarded + registered |
| 0.2 | Onboarded | Pair pairwise via paste-pubkey: A↔B, A↔C, B↔C (copy each identity hex from My Profile, paste+nickname on the other) | All 3 contacts present on each device with nicknames | 3×2 contact rows, names not hex |
| 0.3 | Paired | A→B "baseline 1"; B→A "baseline 2" (both foreground) | Both render in order, both show sent→delivered→read ticks; chat-list preview correct | Bidirectional 1:1 works (10.2 regression intact) |

---

## Family 1 — Delivery matrix (sender × receiver app state)

Sender always foreground (Dev1=alice). Vary **receiver (Dev2=bob)** state. Each cell: A sends a uniquely-worded message; assert it **arrives AND persists on both ends**, with correct ticks.

| # | Receiver state | How to set up | Expected | Pass criteria |
|---|---|---|---|---|
| 1.1 | Foreground, on the chat | B has the A-thread open | Message appears instantly, no notification banner; A sees ✓✓ (delivered) then read tick when B views | Delivered + read, no banner |
| 1.2 | Foreground, elsewhere | B on Chats list (not in A-thread) | Message arrives via WS, in-app; A sees delivered; B sees unread badge/preview | Delivered, persisted |
| 1.3 | Backgrounded (HOME) | `adb -s $S2 shell input keyevent KEYCODE_HOME` | Within ~20s: notification "alice: …"; tap → thread; message persisted; A sees delivered | Notification + persisted + delivered |
| 1.4 | Swipe-killed (natural) | Swipe B from recents (or `am kill`) | FCM wakes BG isolate; notification fires; message persisted cold; A's wake path: `recipient_offline`→`wake_dispatched` | **CRITICAL gate** — message delivered to killed app |
| 1.5 | Force-stopped | `adb -s $S2 shell am force-stop $PKG` | Server logs `wake_dispatched`; client BG handler does NOT run (OS suppression) until B manually launched — then message present (was it queued server-side?) | Document behavior; message must NOT be lost (server offline-queue should hold it) |
| 1.6 | Emulator offline | `adb -s $S2 emu network capture off` OR airplane via settings; A sends; then bring network back | Message delivered after reconnect (server offline queue + client reconnect); no loss | **CRITICAL** — delivered after reconnect |

> 1.5 + 1.6 specifically probe the *server offline queue* (10.4.3a) + client outbox. Note in results whether the message was held server-side and delivered on next connect, or relied on sender retransmit.

---

## Family 2 — Presence (the green tick)

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 2.1 | A foreground, B foreground & connected | Observe A's contact/chat-list badge for B | Green dot next to "bob" within one poll (~25s); thread header "online" | Green when peer online |
| 2.2 | B backgrounds/kills (WS drops) | Wait > poll interval | A's badge for B flips green→amber ("recent", seen <24h); header "last seen Xm ago" | Amber + last-seen text |
| 2.3 | B offline > 24h (simulate: not feasible live — instead verify never-seen) | Pair a contact that has never connected, OR inspect a stale peer | Grey hollow ring; "last seen never"/stale | Grey for stale/never |
| 2.4 | A backgrounds | `am kill`/HOME on A, then bring back | Poller stops in background (no presence polls in logs while paused); resumes + repaints on foreground | No background polling; resumes |
| 2.5 | Group tile | Open Chats with a group present | Group tiles show **no** presence badge | Groups unbadged |

---

## Family 3 — Reliability flush (THE core: stale→online redelivery)

This is the feature's reason for existing. Each case must show a message stranded while a peer is unreachable getting delivered **automatically** when the peer reappears — **no manual resend**.

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 3.1 | B killed/offline so it can't receive; A foreground | A sends "flush-test-1" to B → it can't be delivered (sits in A's outbox; wake may fail if force-stopped) | A's message persisted locally, tick NOT delivered | Message queued, not lost |
| 3.2 | (continues 3.1) | Bring B online (launch B, WS reconnects); A's poller observes B stale→online | A logs `[OR] flush_for_peer peer=… kicked=N` → retransmit → B receives "flush-test-1"; A's tick advances to delivered | **CRITICAL** — auto-delivered on reappear, no manual resend |
| 3.3 | After 3.2 | Inspect B's thread | "flush-test-1" present exactly once (no duplicate from outbox + any wake) | Exactly-once (msgId dedup holds) |
| 3.4 | Rapid flap | Toggle B WS up/down quickly while A has a pending msg | No duplicate sends; message delivered once; A's outbox converges | No double-send under flap (sweep guard) |

---

## Family 4 — Groups (3 members, the reason for Dev3)

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 4.1 | A,B,C paired | A creates group "fam", adds B and C | B + C receive invite (WS or wake); group tile on all 3; system row "alice created…" | Group on all 3 |
| 4.2 | Group exists | A sends "group hi"; B replies "hi from bob" | Fan-out: B+C see "alice: group hi"; A+C see "bob: hi from bob"; sender labels correct | Bidirectional fan-out + labels |
| 4.3 | C killed/offline | A sends "group while C away"; then bring C online | C receives the missed message on reconnect (wake per-peer + outbox flush) | **CRITICAL** — offline group member catches up |
| 4.4 | Group exists | A removes C via Group settings | C sees "removed you" + Left badge; A+B member count 3→2; C can't receive further group msgs | Remove reflected all sides |
| 4.5 | Group exists | B self-leaves | A+C see B left; member count decremented | Leave reflected |

---

## Family 5 — Persistence

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 5.1 | Active chats + group on all 3 | `am force-stop` all 3 → relaunch all 3 | All chats/messages/group state/ticks survive; same identities (pubkeys); libsignal sessions intact (no re-bootstrap) | **CRITICAL** — no record lost across kill |
| 5.2 | (after 5.1) | A→B "after restart"; B→A reply | Works without re-pairing/bundle re-exchange | Sessions persisted |
| 5.3 | Clear-data re-pair | `adb -s $S3 shell pm clear $PKG`; relaunch C → new identity | C re-onboards, auto-registers new pubkey (cache-miss path); re-pair C↔A; A→C delivers to new identity | Re-pair + deliver after clear-data |

---

## Family 6 — Records integrity (the "every record is kept" check)

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 6.1 | Clean state | Open My Profile → Diagnostics on Dev1 | "Stuck outbox" 0, "Orphaned sent" 0, "All records accounted for" | Clean reads clean |
| 6.2 | Strand a message | Make A send to a peer that stays unreachable long enough to leave a pending outbox row (or inspect after 3.1 before flush) | Diagnostics "Stuck outbox" ≥1 (if >24h) OR a pending row visible; orphaned-sent reflects unconfirmed sends | Flags the stranded record |
| 6.3 | Re-kick | Tap "Re-kick stuck outbox" with peer reachable | Stuck peers' outboxes flushed; recompute shows reduced/zero; the message delivers | Re-kick recovers the record |
| 6.4 | Inbound not miscounted | After receiving many messages on Dev2 | Diagnostics "Orphaned sent" stays 0 (inbound rows excluded via known_ticks) | Inbound not false-counted |

---

## Family 7 — Adversarial / chaos

| # | Setup | Action | Expected | Pass |
|---|---|---|---|---|
| 7.1 | A mid-send | Drop A's emulator network the instant after tapping send | Message persists locally; on reconnect, outbox retransmits; delivered once | No loss, no dup |
| 7.2 | Relay reconnect | Restart nothing server-side; drop+restore each client's network | Clients auto-reconnect WS (pingInterval); presence + delivery resume | Auto-recovery |
| 7.3 | Both peers offline at send | A sends to B while both backgrounded; later both foreground | Server offline-queue holds; delivered when B returns | Delivered via queue |
| 7.4 | Presence under churn | Rapidly background/foreground A repeatedly | No poller leak (single in-flight poll), no duplicate flush storms, no crash | Stable under churn |

---

## Reporting

For each case, record in `docs/2026-06-01-emulator-e2e-results.md`:
- **Case id**, **PASS/FAIL/PARTIAL/SKIP**,
- **Evidence** (log excerpt with `[MS]/[Relay]/[OR]/[Presence]/[BG]` + server `[ws]/[presence]/[wake]/[offline]`, screenshot path),
- For failures: **severity** (CRITICAL/HIGH/MEDIUM/LOW) + one-line root-cause hypothesis.

Top of the results doc: device map, build SHA, total cases, pass rate, count of CRITICAL/HIGH, and a **follow-up task list** (each CRITICAL/HIGH → a future task). **No fixes this session.**
