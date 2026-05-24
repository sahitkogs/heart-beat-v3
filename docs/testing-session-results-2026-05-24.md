# Testing session results — heart•beat v1.0.4+5 + server 0.1.5

**Date:** 2026-05-24
**Client:** heart•beat v3 v1.0.4+5 (versionCode 5, `com.sahitkogs.heartbeat`)
**Server:** heartbeat-server `0.1.5-phase10.4.2-bug6-server-wake` @ `34.42.231.29:8080`
**Test pair:** Pixel 8 (1080x2400) ↔ Lenovo Tab TB330XU (1200x1920), both via wifi-adb
**Brief:** `docs/testing-session-prompt.md`

## What we were verifying

Three fixes shipped on 2026-05-23:

1. **v1.0.3** — `deleteContact` now invokes `messageService.forgetPeer()` so
   delete + paste-hex re-pair actually establishes a fresh X3DH session.
2. **v1.0.4** — `RelayClient` survives WS disconnects (keeps `_inbound`
   open across reconnects, exponential backoff 1s → 30s); `send()` throws
   `StateError` when WS is dead, surfacing a "Send failed" snackbar
   instead of a phantom bubble.
3. **Server 0.1.5** — `signaling.Handlers` fires FCM directly on
   `deliver_offline`, closing T13.BUG.6 (bundle pre-key sends + sends
   while sender's WS died now wake the recipient).

## How we drove the test rig

Both devices were reached over wifi-adb. The procedure for each scenario:

- **Pair / connect**: `"<code>`n" | & adb pair <ip>:<port>` (PowerShell
  here-string — Git Bash `echo |` form lacks TTY and fails).
- **Type into Flutter text fields**: switch IME to ADBKeyboard
  (`adb shell ime set com.android.adbkeyboard/.AdbIME`), broadcast text
  with `am broadcast -a ADB_INPUT_TEXT --es msg "..."`, restore Gboard
  on exit.
- **Locate tap targets**: `adb shell "uiautomator dump //sdcard//ui.xml"`
  then `adb pull` and read `bounds="[x1,y1][x2,y2]"`. Flutter Skia
  leaves `text=""` empty but `content-desc` and bounds are accurate.
  Re-dump after typing — the composer grows, shifting the send button
  by ~100px on both devices.
- **Capture client evidence**: `adb exec-out screencap -p > local.png`
  (the more obvious `adb shell screencap -p /sdcard/x.png` failed on
  the tablet).
- **Capture server evidence**:
  `gcloud compute ssh heartbeat-relay --project=heartbeat-app-prod
  --zone=us-central1-a --command='docker logs heartbeat-relay
  --since=Nm --timestamps 2>&1'`
- **Server health check** (validates we're on the right server build):
  `curl http://34.42.231.29:8080/healthz`
  →  `{"ok":true,"version":"0.1.5-phase10.4.2-bug6-server-wake"}`.

### Working coordinate map (for next session)

| Device | Field tap | Send button (empty composer) | Send button (after typing) |
|---|---|---|---|
| Pixel 8 (1080x2400) | (478, 2275) | (1008, 2275) | (1008, 2179) |
| Tablet TB330XU (1200x1920) | (558, 1849) | (1152, 1849) | (1152, 1771) |

### Identities used (verified against server logs)

- **Pixel** display "sahit":
  `700e3fdda0882a7e05fa5e1b8039334d73ff3e5708dbf6d8329a3c839e911cf8`
- **Tablet** display "tablet":
  `7b886963c1d8131352b288ea15c5e64b96e78e3379906b42409654ce47675879`

## Results

| Scenario | Result | Evidence |
|---|---|---|
| **A** Baseline 1:1 send | PARTIAL PASS | A1 first send Pixel→Tablet dropped (no client error, no server log). A2/A3/A4 delivered bidirectionally; verified in UI XML on both devices. |
| **B** Send burst (5 each way) | PASS | All 10 messages (B1–B10) present in order on Pixel and Tablet UI dumps; no drops, no reorder. |
| **C** Recipient backgrounded (FCM wake) | PASS | Server 20:54:25 `[ws] deliver_offline from=700e3f… to=7b8869…` + 20:54:26 `[wake] fcm_ok`. Tablet showed system notification within ~10s; tap opened thread with the message visible. **T13.BUG.6 verified fixed.** |
| **D** WS dropped / auto-reconnect | PASS | Tablet wifi off → server 20:57:08 `[ws] ping_fail` + 20:57:13 disconnect. D1 sent during outage → 20:57:27 `deliver_offline` + `[wake] fcm_ok`. Tablet WS reconnected 20:57:38. D2 sent after wifi recovery delivered as a normal online relay (21:01:34) — confirms v1.0.4 RelayClient reconnect kicks. |
| **E** Delete + re-pair via paste-hex | PASS | Both contacts deleted on each device, then re-added via 64-char hex paste. E1 Tablet→Pixel (16:20) and E2 Pixel→Tablet (16:23) both delivered through fresh X3DH session. **v1.0.3 `forgetPeer` fix verified.** |
| **F** Group chat | PASS | "F_test_group" (2 members) created on Pixel. F1 Pixel→group received by Tablet (16:32); F2 Tablet→group received by Pixel (16:36). Per-member bundle fanout works. |
| **G** Recipient force-stop | SERVER PASS / phone known limitation | After `am force-stop com.sahitkogs.heartbeat` on tablet, server 21:39:31 `deliver_offline` + 21:39:32 `[wake] fcm_ok payloadBytes=261`. Tablet OS surfaced no notification (Android suppresses FCM-data delivery to force-stopped apps — expected). After Tablet relaunch + WS reconnect at 21:41:57, G1 did NOT appear in the thread either. |

## Verdict on the three fix claims

| Claim | Status | Where verified |
|---|---|---|
| v1.0.3 `deleteContact` → `forgetPeer` | ✅ verified | E |
| v1.0.4 `RelayClient` auto-reconnect | ✅ verified | D |
| Server 0.1.5 `deliver_offline → FCM` | ✅ verified | C, D, G all show `[wake] fcm_ok` |

## Open issues / solution proposals

### Issue 1 — A1 first-send drop (PARTIAL in A)

**Observation:** First Pixel→Tablet send after both devices were freshly
foregrounded on the chat thread vanished. No server log, no client
snackbar, no phantom bubble. Subsequent A2–A4, B1–B10, E1, F1 first sends
in their respective scenarios did NOT reproduce it.

**Hypothesis space (not root-caused — needs investigation):**

1. Pixel WS had quietly half-closed during the long pairing/setup
   stretch before A; the v1.0.4 reconnect logic may have fired and
   swallowed the in-flight send instead of throwing `StateError`.
2. UI raced the WS-ready state — composer thought it sent before the
   socket was actually open after foregrounding.
3. Tablet client received the envelope but the session-replay logic
   silently dropped a message it considered out-of-order.

**Proposed next step:** add a one-shot diagnostic log in `RelayClient.send`
that records `(now, wsState, queueDepth)` for every send, and a
matching log in the inbound decrypt path for `(now, msgId, sessionState)`.
Reproduce by fresh-foregrounding both apps and sending immediately.

### Issue 2 — Server doesn't re-flush `deliver_offline` queue on WS reconnect (gap exposed by G)

**Observation:** In G, server correctly recognized the recipient was
offline and fired FCM. But because Android suppressed the FCM data to
the force-stopped app, the tablet never woke. When the tablet was
relaunched manually and its WS reconnected at 21:41:57, the server did
NOT re-deliver the queued G1 envelope — the message was effectively
lost from the recipient's view.

**Proposed fix (server-side):** on WS connect, server should re-flush any
envelopes that were marked `deliver_offline` for that pubkey since the
last successful delivery (cap by age + count to avoid replay storms).
This closes the force-stop / FCM-suppressed gap without depending on
Android delivery behavior.

**Tradeoff:** requires a small persistence layer (or in-memory ring
buffer) of unacked offline envelopes per pubkey. Today the server is
stateless beyond connection tracking. If we stay stateless, the alternative
is documenting "force-stop = message loss" as accepted behavior.

### Issue 3 — Send button shifts after typing (UX nit, not a fix request)

Both composers grow vertically once text is entered, shifting the send
button up by ~100px. Real users tap the button visually so this is
fine — it's only painful for automation. Documenting it here for the
next testing session: always re-dump UI after broadcasting text.

## Files / artifacts produced this session

- Screencaps: `C:\Users\Lambda\Documents\heart-beat\.tmp\pixel_*.png`,
  `tablet_*.png`
- UI dumps: `pixel_ui*.xml`, `tablet_ui*.xml` in the same directory

## Not in scope this session

- Real-keystore signing beyond what Play Internal Testing already provides
- Tatha (second tester) onboarding — explicitly deferred per
  `project_v3_phase_10_4_2_deployed` memory
- Production track promotion
