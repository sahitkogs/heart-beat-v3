---
name: heart-beat-v3-deploy
description: Fast dev-iteration loop for Heart.Beat v3 Flutter client — build debug APK, install on both test devices over wifi adb, launch, screenshot for visual verification. Use whenever the user asks to "deploy", "install", "push to phones", "see it on the phones", or after any UI/Flutter change that needs visual verification.
metadata:
  tags: heartbeat, v3, flutter, android, adb, deploy
---

## When to use

Invoke after any Flutter source change in this repo when the user wants to see the change running on their phones. Also use when they ask to "verify" UI changes visually. The v3 client always tests on **two devices in parallel** so peer-to-peer / two-user flows can be exercised in a single push.

## Environment

Paths assume the repo at `C:\Users\Lambda\Documents\heart-beat-v3`. Adjust if cloned elsewhere.

- **Repo root:** `<repo>` (this folder — the Flutter project root, no `app/` subdir like v1 had)
- **APK output:** `<repo>\build\app\outputs\flutter-apk\app-debug.apk`
- **Flutter CLI:** `C:\Users\Lambda\flutter\bin\flutter.bat` — NOT on PATH, call by full path. On a fresh machine, find it with `where.exe flutter` once it's on PATH, or check `C:\src\flutter\bin\`, `C:\flutter\bin\`, `~\flutter\bin\`.
- **Package id:** `com.heartbeat.app_v3` (deliberately different from v1's `com.heartbeat.app` so both can coexist on a device)
- **Test devices (v3 pair, per `project_test_devices` memory):**
  - **Device A — Pixel 8** at `10.0.0.191:<port>` (wifi-adb port rotates every session)
  - **Device B — Lenovo TB330XU tablet** at `10.0.0.86:<port>` (likewise)
- **Shell:** Bash (Git Bash) and PowerShell both work for v3 adb. The v1-era warning about `/sdcard/*` path mangling is irrelevant here because we use `exec-out screencap -p > localfile.png` instead of pulling from device storage.

## The loop

Standard cycle: edit → build → install on both → launch on both → screencap each → downsize → read.

### 1. Build debug APK

```powershell
Set-Location 'C:\Users\Lambda\Documents\heart-beat-v3'
& "C:\Users\Lambda\flutter\bin\flutter.bat" build apk --debug
```

~45–90s incremental, ~3–4 min from cold. Output: `build\app\outputs\flutter-apk\app-debug.apk`.

### 2. Install on both devices

```bash
APK="/c/Users/Lambda/Documents/heart-beat-v3/build/app/outputs/flutter-apk/app-debug.apk"
adb -s 10.0.0.191:<pixel-port> install -r "$APK"
adb -s 10.0.0.86:<tablet-port> install -r "$APK"
```

`-r` reinstalls preserving app data (profile, contacts, signal sessions). Drop `-r` and add `adb -s … uninstall com.heartbeat.app_v3` first if you want a clean-slate test (e.g., to exercise the DisplayNameSetupScreen first-launch gate).

### 3. Launch on both

```bash
adb -s 10.0.0.191:<pixel-port> shell monkey -p com.heartbeat.app_v3 -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
adb -s 10.0.0.86:<tablet-port> shell monkey -p com.heartbeat.app_v3 -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 5   # give Firebase init + Flutter first frame time on both
```

### 4. Screenshot + downsize for inline view

The Read tool can't render full-resolution device screenshots (Pixel 8 is 1080×2400 ≈ 60 KB at thumbnail; the tablet is 1200×1920). Always thumbnail to 600px wide before reading.

```bash
adb -s 10.0.0.191:<pixel-port> exec-out screencap -p > /c/Users/Lambda/Documents/heart-beat/.tmp/pixel.png
adb -s 10.0.0.86:<tablet-port>  exec-out screencap -p > /c/Users/Lambda/Documents/heart-beat/.tmp/tablet.png
```

```powershell
python -c "
from PIL import Image
import os
d = r'C:\Users\Lambda\Documents\heart-beat\.tmp'
for f in ['pixel.png','tablet.png']:
    im = Image.open(os.path.join(d,f))
    im.resize((600, int(600*im.size[1]/im.size[0]))).save(os.path.join(d, f.replace('.png','_sm.png')))
"
```

Then `Read` the `_sm.png` files.

## Reconnect over wifi (port changed / "device offline")

`adb devices` shows a device as `offline` whenever the phone's wireless-debugging port has rotated (typical after a screen-off period or device reboot). Ask the user to open **Settings → Developer options → Wireless debugging** on the affected device and read off the three values:

- **Pairing code** (6 digits, expires fast)
- **Pair port** (`<IP>:<pair-port>` under "Pair device with pairing code")
- **Connect port** (`<IP>:<connect-port>` under the device's name)

Then:

```bash
echo "<pair-code>" | adb pair 10.0.0.<X>:<pair-port>
adb connect 10.0.0.<X>:<connect-port>
adb devices    # confirm the connect address shows 'device' (not 'offline')
```

The connect address is what goes in `-s` afterward. TLS handshake occasionally faults on first try — retry with fresh values from a re-opened pairing dialog. (For session continuity: memory `project_test_devices` documents this rotation pattern.)

## Navigation tricks

Scaling: Pixel 8 (1080×2400) — multiply 600-resized coords by `1080/600 ≈ 1.8`. Tablet (1200×1920) — multiply by `1200/600 = 2.0`.

- **Tap pencil FAB on home (Pixel):** `adb -s 10.0.0.191:<port> shell input tap 980 2240`
- **Tap settings/gear icon top-right (Pixel):** `adb -s 10.0.0.191:<port> shell input tap 1010 192`
- **Tap composer text field (chat thread open, keyboard not up):** `(450, 2280)` on Pixel
- **Tap send arrow (composer focused, keyboard up):** `(1016, 1565)` on Pixel
- **Force portrait:** `adb -s <device> shell settings put system accelerometer_rotation 0 && adb -s <device> shell settings put system user_rotation 0`
- **Force-stop:** `adb -s <device> shell am force-stop com.heartbeat.app_v3`
- **Hard kill specifically (avoid the force-stop FCM-suppression flag — see Gotchas below):** swipe the app from recents instead.

When something doesn't tap-through, screenshot first, work out coords from the resized image, then multiply by the scale factor.

## Tail logcat from one or both devices

Common filters used in this codebase:

```bash
# Client-side message events (MS = MessageService, Relay = WS client)
adb -s 10.0.0.191:<pixel-port> logcat -d -v time | grep -E 'flutter.*\[(MS|Relay)\]'

# Background isolate (BG handler, FCM wake, notification)
adb -s 10.0.0.86:<tablet-port> logcat -d -v time | grep -iE 'flutter.*\[BG\]|RingtonePlayer|FLTFireBGExecutor|Start proc.*heartbeat'

# Was the app actually killed? Looking for the kernel kill event:
adb -s <device> logcat -d -v time | grep -iE 'ActivityManager.*Killing.*heartbeat'
```

Clear before a fresh test: `adb -s <device> logcat -c`. (Don't do this if you're trying to inspect something that already happened — buffers can't be recovered after `-c`.)

## Server-side correlation

Client logs alone often don't tell you why a message didn't land. The relay logs `[ws] connect/disconnect/ping_fail/deliver_offline` events since `0.1.4-phase10.4.1-bug6` (commit `d3a3731` in `heartbeat-server`). Tail them while reproducing:

```bash
gcloud compute ssh heartbeat-relay --project=heartbeat-app-prod \
  --zone=us-central1-a --command='sudo docker logs -f --tail 50 heartbeat-relay'
```

When triaging "I sent but didn't receive" issues, look at the three logs side-by-side: sender's `[MS]/[Relay]`, server's `[ws]`, receiver's `[BG]/[Relay]`.

## Gotchas

- **`adb shell am force-stop` ≠ a natural kill.** It puts the app into Android's "stopped" state, which suppresses implicit-broadcast delivery (including FCM data messages) until the user manually launches the app once. So tests that force-stop the receiver and then expect FCM wake to fire will see the server-side wake go out but the client-side BG handler never run. **Workaround:** launch the app once to clear the flag, OR swipe from recents (which is what users actually do).
- **Drift watch() streams don't cross isolates.** When the FCM BG handler in its own isolate inserts a row, the main-isolate UI doesn't see it until something invalidates the stream. `T13.BUG.3` wired `AppLifecycleState.resumed` to invalidate `chatsStreamProvider`, `chatThreadProvider`, etc., so backgrounding-and-returning refreshes correctly. If you add a new drift-backed provider, add it to the invalidation list in `_HeartbeatV3AppState.didChangeAppLifecycleState` (in `lib/main.dart`).
- **WS isn't connected until you open a chat (pre-`T13.BUG.5` regression).** Fixed in commit `be052f5` by pre-warming `messageServiceProvider` in `ChatListScreen.initState`. If you remove that or refactor it away, every inbound forces an FCM wake even when the app is foreground, and the BG-isolate path will starve the main-isolate UI.
- **Notification cold-launch routing race (`T13.BUG.1`).** Fixed by moving cold-launch routing into `StartupRouter` (in `lib/main.dart`). Don't add a duplicate post-frame push from `HeartbeatV3App.initState` — that's exactly what raced the `pushReplacementNamed('/chats')` and dropped the user on home instead of the chat thread.
- **Decrypt-fail in BG handler used to silently swallow the notification.** Now (`T13.BUG.2`) distinguishes `DuplicateMessageException` (silent — already delivered) from other errors (generic "New message" banner). If you touch the BG decrypt path, keep this branching.
- **Two devices have different identity scales** — Pixel 8 = portrait 1080×2400, tablet = portrait 1200×1920. When converting screenshot coords for tap input, use the right scale for the right device. Tablet is roughly square-ish, Pixel is tall.

## Test data conventions

- **Pixel's displayName** = `sahit` (or `sahit-v2` after `T13.UX.10` rename test)
- **Tablet's displayName** = `tablet`
- **Pixel's pubkey** = `2de8f8ec3eb056c232b1ada19e447982f1b961df39ba5e61231963209991beba`
- **Tablet's pubkey** = `ba537d0b8979f756dee7c0c9e81faed55d7372b91df546883a576ae3d7610f8d`

The standard E2E group fixture is `F3-test` (chatId `5bebf4...102e99`), created by Pixel during phase 10.4.1 device E2E. Useful pre-existing surface for any new group-related test.

## After deploying

Always end by reading the captured screenshot(s) and reporting what's visible — confirm the change landed before declaring the task complete. Do not claim a UI change works without visual verification. For peer-to-peer flows, verify on **both** devices.

## Reference

- Source repo: `https://github.com/sahitkogs/heart-beat-v3`
- Current shipped version: `v0.1.0-phase10.4.1` (commit `be052f5`)
- Server deploy: see `heartbeat-server-deploy` skill in `heartbeat-server` repo
- Roadmap: `docs/heartbeat-roadmap.md` in the parent `heart-beat` repo
