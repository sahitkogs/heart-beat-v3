# Testing session prompt — heart•beat v1.0.4+5

Paste the body below as the opening message of a fresh Claude session. It briefs you on the recent fixes, the test rig, and the scenarios to exercise.

---

```
Test heart•beat messaging end-to-end after the bug-fix burst on 2026-05-23
(v3 client v1.0.4+5 + heartbeat-server 0.1.5-phase10.4.2-bug6-server-wake).

# What was fixed (don't re-debug, just verify)

1. v1.0.3 — `deleteContact` now calls `messageService.forgetPeer()` to
   clear the stale peer bundle row + libsignal session, so delete +
   re-pair via paste-hex actually establishes a fresh X3DH session.
2. v1.0.4 — `RelayClient` survives WS disconnects: keeps `_inbound`
   open across reconnects, auto-reconnects with exponential backoff
   (1s → 30s cap), and `send()` throws `StateError` when the WS is
   dead so the composer surfaces a real "Send failed" snackbar instead
   of a phantom bubble.
3. Server 0.1.5 — `signaling.Handlers` now fires FCM directly on
   `deliver_offline`, closing T13.BUG.6. Bundle pre-key sends and
   sends-while-sender's-WS-died both wake the recipient now.

# Test rig

Two physical devices reachable via wifi-adb. Both run heart•beat
v1.0.4+5 (versionCode 5) installed from Play Store Internal Testing.

- **Pixel 8**: 1080x2400 screen, applicationId `com.sahitkogs.heartbeat`.
  wifi-adb ports rotate — if `adb devices` doesn't show it, ask the user
  for fresh pairing info and use the `reference_wifi_adb_pair` memory
  pattern (`"<code>\`n" | & adb pair <ip>:<port>`).
- **Tablet (Lenovo TB330XU)**: 1200x1920 screen, same applicationId.
  Same wifi-adb-rotates caveat.

These two phones ARE the test pair — there is no third device. Do not
invent extra users or pubkeys. Whichever display names happen to be
configured on each phone are what they are; read them from the My
Profile screen if you need to know.

- **ADBKeyboard** is installed + enabled but NOT default on both. See
  `reference_adbkeyboard` memory for the full workflow: `adb shell
  ime set com.android.adbkeyboard/.AdbIME` → broadcast text via
  `am broadcast -a ADB_INPUT_TEXT --es msg "..."` → restore Gboard
  (`com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME`)
  when done. Switch on entry to each scenario, restore on exit.
- **Server logs**:
  `gcloud compute ssh heartbeat-relay --project=heartbeat-app-prod --zone=us-central1-a --command='docker logs heartbeat-relay --tail=N --timestamps 2>&1'`
- **Server health**:
  `curl http://34.42.231.29:8080/healthz` should return
  `{"ok":true,"version":"0.1.5-phase10.4.2-bug6-server-wake"}` — if it
  doesn't, the server isn't on the version we're testing against and
  the whole exercise is invalid.

# Skills you should use (these capture hard-won caveats)

- **`heart-beat-v3-deploy`** (in `C:\Users\Lambda\Documents\heart-beat-v3\.claude\skills\`)
  — debug iteration loop for the v3 Flutter client on both test devices.
  Build APK, install via wifi-adb, launch, screencap. Use it whenever
  you need to push a code change to verify a hypothesis.
- **`heartbeat-play-release`** (in `C:\Users\Lambda\Documents\heart-beat\.claude\skills\`)
  — Play Store release loop. Use it if a test failure requires
  shipping a real fix to testers (bump pubspec, build appbundle,
  upload via `tools/upload_to_play.py`).
- **`heartbeat-server-deploy`** (in `C:\Users\Lambda\Documents\heartbeat-server\.claude\skills\`)
  — server deploy. **Read the warning section before touching the VM.**
  The GCP e2-micro OOM-thrashes on in-VM `docker build`; use the fast
  path (cross-compile locally + scp + thin distroless on VM) every
  time. If you accidentally wedge the VM, the skill has the recovery
  recipe.
- **`superpowers:systematic-debugging`** if any scenario fails. Don't
  propose fixes without root-causing first.

# Scenarios

Pick an order that builds confidence fastest. State the expected
behavior BEFORE running each, then capture evidence (server log
timestamps + screencap) to confirm. Don't claim PASS without both
client AND server evidence.

- **A. Baseline 1:1 send.** Both apps foreground on the same chat
  thread between Pixel and Tablet. Pixel sends → Tablet receives
  within ~3s. Tablet replies → Pixel receives.
- **B. Send burst.** Each side sends 5 messages back-to-back. All 10
  arrive on both sides in order, no drops.
- **C. Recipient backgrounded (FCM wake path).** Press home on the
  Tablet (NOT force-stop). Pixel sends. Server log should show
  `[ws] deliver_offline ...` followed by `[wake] fcm_ok ...`. Tablet
  should fire a push notification within ~10s. Tap it → message
  visible in chat.
- **D. Recipient WS dropped (auto-reconnect path).** With both apps
  foreground, toggle the Tablet's wifi off for 20s then back on.
  Pixel sends one message DURING the off-window and one AFTER wifi
  returns. Expected: the during-off-window send either snackbar-fails
  ("Send failed: Bad state: relay disconnected") or triggers
  deliver_offline → FCM wake. The after-wifi-returns send should
  deliver normally — confirms client auto-reconnect kicked.
- **E. Delete + re-pair via paste-hex (regression for v1.0.3 fix).**
  On both devices: delete the contact, then re-add the other phone's
  pubkey via paste-hex. Send → should deliver. This was 100% broken
  before v1.0.3.
- **F. Group chat.** Create a group containing both phones. Both
  send messages → both receive all messages. Exercises the
  group-fanout + per-member bundle exchange path.
- **G. Recipient force-stop (the original T13.BUG.6 surface).**
  Force-stop heart•beat on the Tablet (`adb shell am force-stop
  com.sahitkogs.heartbeat`). Pixel sends. Server should fire FCM.
  Note: per the `heartbeat-server-deploy` skill caveats, Android
  suppresses implicit-broadcast delivery (including FCM data) to
  force-stopped apps, so the phone may NOT actually wake regardless
  of server behavior — that's an OS quirk. Document whether server
  log shows `[wake] fcm_ok` (success on our side) even if the
  phone doesn't surface the notification.

# How to drive UI without bothering the user

ADBKeyboard for typing into text fields. For taps, `adb shell input
tap <x> <y>` using raw pixel coordinates (screen sizes above).
`uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml` gives
coarse-rect bounds — Flutter Skia compositing means every label is
empty, but the bounding boxes are accurate enough to locate rows.

# Reporting

End the session with a compact table:

| Scenario | Result | Evidence |
|---|---|---|
| A | PASS | server log 14:30:01 deliver Pixel→Tablet |
| ... | ... | ... |

Don't restate the diagnosis of what was broken before — that's in
`project_v3_phase_10_4_2_deployed.md` memory and the recent git logs
of `heart-beat-v3` + `heartbeat-server`. Focus on what's currently
working vs. still broken.

# Stop and ask the user before

- Uninstalling either app (would wipe local identities + force a
  re-pair coordination we can't do alone).
- Adding a new tester to Play Console.
- Deploying any server change (use the heartbeat-server-deploy skill
  if approved, never do an on-VM docker build).
- Anything that costs money or touches production beyond local
  device state.

If a scenario fails, use `superpowers:systematic-debugging` to root-
cause before proposing fixes.
```
