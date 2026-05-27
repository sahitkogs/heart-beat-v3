# Task 17 — Continuation Playbook (next session)

Phase 10.4.3b two-emulator E2E verification, picked up after a Claude Code restart so the new session can use the `android-alice` + `android-bob` MCP servers.

## Where we left off

- All code commits through Task 15 (`36db830 message_service: forgetPeer cascades outbox cleanup`) on `main`.
- Quality gates pass: `flutter test` = 245 ✅ / 3 skipped, `flutter analyze` baseline only, `flutter build apk --debug` clean.
- Two emulators booted: `emulator-5554` (port 5554) and `emulator-5556` (port 5556).
- Two AVDs: `Heartbeat` (existing) and `Heartbeat2` (cloned from it). Both x86_64, `google_apis_playstore` system image (FCM works).
- `v6.apk` (181 MB, SHA C023AE41…) at `C:\Users\Lambda\AppData\Local\Temp\hb-v3-apks\v6.apk` — pre-Phase-2 client, schemaVersion 6.
- `v7.apk` (206 MB, SHA 9C9968A6…) at `C:\Users\Lambda\AppData\Local\Temp\hb-v3-apks\v7.apk` — current main, schemaVersion 7.
- v6.apk already installed on `emulator-5554`, app launched, display-name set to `Alice`, notifications allowed. No contacts or chats yet.
- v6.apk NOT installed on `emulator-5556` yet.
- `android-remote-control-mcp` v1.7.0 APK installed on both emulators, configured headless, MCP server running on each:
  - emulator-5554: device-slug `alice`, bearer `alice-token`, host port `localhost:18080` → device 8080
  - emulator-5556: device-slug `bob`, bearer `bob-token`, host port `localhost:18081` → device 8080
- `.mcp.json` written at repo root (gitignored). New session will auto-discover the two HTTP MCP servers and surface tools as `android_alice_*` and `android_bob_*`.

## First actions in the new session

1. Verify the MCP tools loaded — call `android_alice_get_screen_state` and `android_bob_get_screen_state`. If you see the heart•beat home screen on alice (one chat-list with "No chats yet") and a fresh launcher on bob, the wiring is good.
2. If either MCP server isn't responding, the host adb forwards may have been dropped. Re-run:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 forward tcp:18080 tcp:8080
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5556 forward tcp:18081 tcp:8080
   ```
   Restart the on-device server with:
   ```powershell
   $appId = "com.danielealbano.androidremotecontrolmcp.debug"
   $startComp = "$appId/com.danielealbano.androidremotecontrolmcp.services.mcp.AdbServiceTrampolineActivity"
   & adb -s emulator-5554 shell am start -n $startComp --es action start
   & adb -s emulator-5556 shell am start -n $startComp --es action start
   ```
3. If the emulators were shut down, restart with `-no-snapshot-save` so user data is preserved across runs (the v6 state on emulator-5554 is what F1 needs).

## Scenarios to run

The plan (`docs/2026-05-26-client-receipts-implementation-plan.md` Task 17) defines F1–F6. Run in this order so each leaves a useful state for the next.

### F1 — Migration v6 → v7

1. **State going in:** alice on v6 with display name set, no contacts. bob has no app yet.
2. Install v6.apk on emulator-5556. Drive setup, set display name `Bob`, allow notifications.
3. Pair alice ↔ bob via paste-hex flow:
   - On alice: Settings → copy own pubkey hex.
   - On bob: Contacts → Add → paste hex → name "Alice".
   - On bob: Settings → copy own pubkey hex.
   - On alice: Contacts → Add → paste hex → name "Bob".
4. Open bob's chat with Alice from bob, send `hi v6` from bob → alice.
5. Verify alice receives `hi v6`. (v6 has no ticks — confirm the message lands.)
6. From the host: `adb -s emulator-5554 install -r -t v7.apk` (upgrade in-place), same for emulator-5556.
7. Relaunch both apps. **Migration verifications:**
   - Existing chat with the peer is still present in the chat list.
   - Existing messages are still visible.
   - New outbound message from bob → alice shows a single check (✓) tick within ~1s.
   - `adb logcat | findstr /R "MS receipt_applied retransmit"` shows the receipt path firing.

### F2 — Happy-path delivered + read tick

1. Both phones are on v7 from F1.
2. Alice in foreground viewing the chat with bob. Bob sends "hello".
3. Bob's bubble: ✓ → ✓✓ within a few seconds → ✓✓ accent color when alice's UI re-renders the bubble (read receipt).
4. Alice's inbound bubble: no tick.

### F3 — Recipient offline (Issue #2)

1. Force-stop alice's app: `adb -s emulator-5554 shell am force-stop com.sahitkogs.heartbeat`.
2. Bob sends "while-offline". Bob's bubble: ✓ (sent), no ✓✓ yet.
3. Wait ~5s. Confirm FCM wake reaches alice: `adb -s emulator-5554 logcat | findstr /R "FCM bg_isolate wake"`.
4. Cold-launch alice: `adb -s emulator-5554 shell am start -n com.sahitkogs.heartbeat/.MainActivity`. Alice ingests `while-offline`.
5. Bob's bubble flips ✓ → ✓✓ within a few seconds → ✓✓ accent once alice's UI shows the message.

> Note: emulator FCM works because both AVDs use `google_apis_playstore`. If FCM doesn't fire, capture `adb logcat` and skip to F4 — this isn't necessarily a regression in our code, could be emulator GMS state.

### F4 — Sender retransmit on half-dead WS (Issue #1)

1. Wire-disconnect bob mid-send: `adb -s emulator-5556 shell svc data disable` (or `svc wifi disable` if on wifi networking).
2. Bob sends "halfdead". Outbox row is inserted; encrypt + send may surface a failure, swallowed per Task 6.
3. Within ~30s the retransmitter sweeps. Bob's bubble stays at ✓.
4. Re-enable network: `adb -s emulator-5556 shell svc data enable`.
5. Within the next sweep (~10s), bob's bubble flips to ✓✓.

### F5 — 24h expiry → failed tick → tap-to-retry

Hard to stage in real time, so the plan calls for a one-shot constant tweak. Workflow:

1. In `lib/chat/outbox_retransmitter.dart` change `static const maxAge = Duration(hours: 24);` to `Duration(minutes: 1);`. Rebuild `flutter build apk --debug`, install on bob.
2. Bob sends "permaoffline" to a peer that is permanently offline (e.g. force-stop alice and leave it).
3. Wait ~70s. Bob's bubble flips to ⚠ (failed). Tap the icon → bubble resets to ✓ and another sweep retries.
4. **Revert** `maxAge` to `Duration(hours: 24)` before any further commit.

### F6 — Contact delete cascade

1. With unacked outbox rows present for alice (force-stop alice first), bob deletes the alice contact (tap chat header → Delete contact).
2. From bob's logcat: `adb -s emulator-5556 logcat -d | findstr "[OR]"` shows no further `retransmit msgId=...` lines for alice's pubkey after the delete. Existing rows for any other peer (none in this test) should be untouched.

## Results doc

After every scenario, append PASS/FAIL + a one-line note to `docs/testing-session-results-2026-05-26-10.4.3b.md` (create it from the template in plan §17 step 7). Commit at the end with:

```
docs: 10.4.3b two-emulator E2E results
```

## When all six are done

Move to Task 18: bump pubspec version (currently `1.0.4+5`; pick the next available Play `versionCode`), build release APK + AAB, tag `v1.0.3-phase10.4.3b`. **Do not push or upload.** The user pushes + uploads manually after reviewing.

## Cleanup at the end of the session

- Stop the MCP servers: `adb -s emulator-5554 shell am start -n com.danielealbano.androidremotecontrolmcp.debug/...AdbServiceTrampolineActivity --es action stop` (same for 5556).
- Shutdown emulators if desired: `adb -s emulator-5554 emu kill` and `adb -s emulator-5556 emu kill`.
- The cloned `Heartbeat2` AVD stays; delete with `avdmanager delete avd -n Heartbeat2` if you want.
