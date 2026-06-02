# Contact Sharing + Deep Links — Implementation Plan

> **STATUS: ✅ SHIPPED 2026-06-01** at `v1.2.0+12`, tag `v1.2.0-contact-sharing` (18 commits on `main`, `30ab05d`…`598ed21`). All 13 tasks done via subagent-driven development; quality gates green (296 tests pass, `flutter analyze` clean apart from the pre-existing `hex_codec` info, debug APK builds with both share plugins coexisting). See the **As-built notes & deviations** section at the bottom for what diverged from this plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "You" in group settings, share-my-contact + share-a-contact via a single https add-link (landing page → `intent://` → app or Play Store), and make heart•beat a share target that forwards a contact link into a chosen chat.

**Architecture:** One testable core (`ContactLink` build/parse) feeds every outbound share (`share_plus`) and the inbound deep-link handler (`app_links`, `heartbeat://add`). A static landing page on the existing GitHub Pages bridges https→app/Play-Store. heart•beat registers as a `text/plain` share target (`receive_sharing_intent`); received text sets a pending-share provider that puts Chats-home into "forward mode".

**Tech Stack:** Flutter / Riverpod / drift; new deps `share_plus`, `app_links`, `receive_sharing_intent`; Android manifest intent-filters; static HTML on GitHub Pages (`docs/`).

**Spec:** `docs/2026-06-01-contact-sharing-design.md`

**Conventions:** `$env:PATH = "C:\Users\Lambda\flutter\bin;" + $env:PATH`; `flutter test` / `flutter analyze` / `flutter build apk --debug`. Package name `app_v3`. Commit on `main`, one commit per task, message `<area>: <terse> (T#)`. App id `com.sahitkogs.heartbeat`. Pages base `https://sahitkogs.github.io/heart-beat-v3/` (main:/docs).

---

## File structure

| File | Responsibility | New/Modify |
|---|---|---|
| `lib/features/contacts/contact_link.dart` | Build + parse the add-link (the testable core) | **Create** |
| `docs/add/index.html` | Pages landing page: https → `intent://` → app/Play Store | **Create** |
| `android/app/src/main/AndroidManifest.xml` | VIEW (`heartbeat://add`) + SEND (`text/plain`) intent-filters | Modify |
| `pubspec.yaml` | `share_plus`, `app_links`, `receive_sharing_intent` | Modify |
| `lib/features/chat/group_settings_screen.dart` | "You" for self | Modify |
| `lib/features/identity/identity_screen.dart` | "Share contact" button | Modify |
| `lib/features/contacts/contact_actions.dart` | `shareContact(...)` helper | Modify |
| `lib/features/chat/chat_thread_screen.dart` | "Share contact" in header sheet; composer prefill | Modify |
| `lib/features/contacts/add_contact_screen.dart` | `initialHex`/`initialName` prefill | Modify |
| `lib/features/sharing/pending_share_provider.dart` | `pendingShareTextProvider` (forward mode) | **Create** |
| `lib/features/chat/chat_list_screen.dart` | forward-mode banner + tap-to-forward | Modify |
| `lib/main.dart` | wire app_links + receive_sharing_intent (cold + warm) → routing | Modify |

---

## Phase F1 — "You" in group settings

### Task 1: Show "You" for the current user

**Files:**
- Modify: `lib/features/chat/group_settings_screen.dart` (member label ≈ lines 201–211; creator header ≈ line 129)

- [x] **Step 1: Read the file** to confirm: `final me = ref.watch(identityProvider).valueOrNull?.publicKeyHex ?? '';`, `final memberIsMe = member.memberPubkeyHex == me;`, the `memberLabel = resolveName(...)` line, the `if (memberIsMe) const _Badge(label: 'you')`, and the creator header `creator == me ? 'you' : resolveName(...)`.

- [x] **Step 2: Edit the member label** — replace the `resolveName` assignment so self is "You", and remove the now-redundant `'you'` badge:
```dart
final memberLabel = memberIsMe
    ? 'You'
    : resolveName(member.memberPubkeyHex, contactsByPk[member.memberPubkeyHex]);
```
Delete the `if (memberIsMe) const _Badge(label: 'you'),` line (the label now says "You"). If `_Badge` becomes unused after this, leave it (it may be used elsewhere) — only remove the usage.

- [x] **Step 3: Capitalize the creator header self-ref** — change `creator == me ? 'you'` to `creator == me ? 'You'`.

- [x] **Step 4: Verify**

Run: `flutter analyze lib/features/chat/group_settings_screen.dart`
Expected: no new issues (pre-existing `hex_codec` info elsewhere is fine). Then `flutter test` stays green.

- [x] **Step 5: Commit**
```bash
git add lib/features/chat/group_settings_screen.dart
git commit -m "ui: show current user as \"You\" in group settings (T1)"
```

---

## Phase F2 — Foundation: ContactLink + deps + landing page + manifest

### Task 2: Add dependencies

**Files:** Modify `pubspec.yaml`

- [x] **Step 1: Add deps** under `dependencies:` (use latest compatible; these are the known-good majors):
```yaml
  share_plus: ^10.1.4
  app_links: ^6.3.2
  receive_sharing_intent: ^1.8.1
```

- [x] **Step 2: Resolve**

Run: `flutter pub get`
Expected: resolves without conflict. If a version is unavailable, pick the nearest resolvable major and note it.

- [x] **Step 3: Commit**
```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: share_plus + app_links + receive_sharing_intent (T2)"
```

### Task 3: `ContactLink` helper (the testable core)

**Files:**
- Create: `lib/features/contacts/contact_link.dart`
- Test: `test/features/contacts/contact_link_test.dart`

- [x] **Step 1: Write the failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app_v3/features/contacts/contact_link.dart';

void main() {
  const hex = '116d49edaaee117f9f048fc1803b272412e3103dbd1f98971d5a77cb24e8c19b';

  test('toUri builds the https add-link with k and url-encoded n', () {
    final u = const ContactLink(hex, 'Al Ice').toUri();
    expect(u.scheme, 'https');
    expect(u.path, '/heart-beat-v3/add/');
    expect(u.queryParameters['k'], hex);
    expect(u.queryParameters['n'], 'Al Ice');
    expect(u.toString(), contains('n=Al%20Ice'));
  });

  test('toUri omits n when name is null/empty', () {
    expect(const ContactLink(hex, null).toUri().queryParameters.containsKey('n'), isFalse);
    expect(const ContactLink(hex, '').toUri().queryParameters.containsKey('n'), isFalse);
  });

  test('parse accepts the https landing URL', () {
    final c = ContactLink.parse(Uri.parse('https://sahitkogs.github.io/heart-beat-v3/add/?k=$hex&n=Al%20Ice'));
    expect(c, isNotNull);
    expect(c!.pubkeyHex, hex);
    expect(c.name, 'Al Ice');
  });

  test('parse accepts the heartbeat:// deep link', () {
    final c = ContactLink.parse(Uri.parse('heartbeat://add?k=$hex&n=Bob'));
    expect(c!.pubkeyHex, hex);
    expect(c.name, 'Bob');
  });

  test('parse rejects a non-64-hex k', () {
    expect(ContactLink.parse(Uri.parse('heartbeat://add?k=zzzz')), isNull);
    expect(ContactLink.parse(Uri.parse('heartbeat://add?n=Bob')), isNull); // no k
  });

  test('parse tolerates missing n', () {
    final c = ContactLink.parse(Uri.parse('heartbeat://add?k=$hex'));
    expect(c!.pubkeyHex, hex);
    expect(c.name, isNull);
  });
}
```

- [x] **Step 2: Run, confirm FAIL**

Run: `flutter test test/features/contacts/contact_link_test.dart`
Expected: FAIL — `ContactLink` undefined.

- [x] **Step 3: Implement**
```dart
/// The add-contact link shared via QR-less channels (WhatsApp, etc.) and
/// consumed by the heartbeat://add deep link. Carries the pubkey (k) and an
/// optional display name (n). This is the single encode/parse point.
class ContactLink {
  const ContactLink(this.pubkeyHex, this.name);
  final String pubkeyHex;
  final String? name;

  static final Uri _base = Uri.parse('https://sahitkogs.github.io/heart-beat-v3/add/');
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// The shareable https URL.
  Uri toUri() => _base.replace(queryParameters: {
        'k': pubkeyHex,
        if (name != null && name!.isNotEmpty) 'n': name!,
      });

  /// Parse either the https landing URL or the heartbeat://add deep link.
  /// Returns null unless `k` is a valid 64-char lowercase hex pubkey.
  static ContactLink? parse(Uri uri) {
    final k = uri.queryParameters['k']?.trim().toLowerCase();
    if (k == null || !_hex64.hasMatch(k)) return null;
    final n = uri.queryParameters['n'];
    return ContactLink(k, (n != null && n.isNotEmpty) ? n : null);
  }
}
```

- [x] **Step 4: Run, confirm PASS**

Run: `flutter test test/features/contacts/contact_link_test.dart`
Expected: PASS (6 tests). Then full `flutter test`.

- [x] **Step 5: Commit**
```bash
git add lib/features/contacts/contact_link.dart test/features/contacts/contact_link_test.dart
git commit -m "contacts: ContactLink build/parse helper (T3)"
```

### Task 4: Landing page on GitHub Pages

**Files:** Create `docs/add/index.html`

- [x] **Step 1: Create the page** (no test — static asset; verified manually in F6):
```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Add me on heart•beat</title>
<style>
  body { font-family: Georgia, serif; background:#f3ede1; color:#2b2b2b;
         display:flex; min-height:100vh; align-items:center; justify-content:center; margin:0; }
  .card { text-align:center; max-width:22rem; padding:2rem; }
  h1 { font-size:1.6rem; } .name { color:#b4583a; }
  a.btn { display:inline-block; margin-top:1rem; padding:.7rem 1.4rem; background:#b4583a;
          color:#fff; border-radius:.6rem; text-decoration:none; }
  code { word-break:break-all; font-size:.8rem; color:#555; }
</style>
</head>
<body>
<div class="card">
  <h1>Add <span class="name" id="who">someone</span> on <strong>heart•beat</strong></h1>
  <p id="hint">Opening the app…</p>
  <a class="btn" id="open" href="#">Open in heart•beat</a>
  <p style="margin-top:1.5rem"><small>Or paste this code into heart•beat → Add contact → Paste hex:</small><br/><code id="key"></code></p>
</div>
<script>
  var q = new URLSearchParams(location.search);
  var k = (q.get('k')||'').trim();
  var n = q.get('n')||'';
  if (n) document.getElementById('who').textContent = n;
  document.getElementById('key').textContent = k;
  var play = 'https://play.google.com/store/apps/details?id=com.sahitkogs.heartbeat';
  // Android intent: open the app via the heartbeat:// scheme, else Play Store.
  var intent = 'intent://add?k=' + encodeURIComponent(k) + '&n=' + encodeURIComponent(n) +
    '#Intent;scheme=heartbeat;package=com.sahitkogs.heartbeat;' +
    'S.browser_fallback_url=' + encodeURIComponent(play) + ';end';
  var isAndroid = /android/i.test(navigator.userAgent);
  document.getElementById('open').href = isAndroid ? intent : play;
  if (isAndroid && k) {
    document.getElementById('hint').textContent = 'If nothing happens, tap the button below.';
    window.location.href = intent;            // auto-attempt
  } else {
    document.getElementById('hint').textContent = 'Open this link on your Android phone to add the contact.';
  }
</script>
</body>
</html>
```

- [x] **Step 2: Commit** (Pages redeploys on push to main:/docs)
```bash
git add docs/add/index.html
git commit -m "pages: add-contact landing page (intent:// -> app or Play Store) (T4)"
```

### Task 5: Android manifest intent-filters

**Files:** Modify `android/app/src/main/AndroidManifest.xml`

- [x] **Step 1: Read** the `<activity android:name=".MainActivity" …>` block (currently only MAIN/LAUNCHER).

- [x] **Step 2: Add two intent-filters** inside the MainActivity `<activity>` element, after the existing MAIN/LAUNCHER filter:
```xml
            <!-- Add-contact deep link from the landing page -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="heartbeat" android:host="add"/>
            </intent-filter>
            <!-- heart•beat as a share target for plain text -->
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
```

- [x] **Step 3: Verify it builds**

Run: `flutter build apk --debug`
Expected: build succeeds (manifest merges cleanly).

- [x] **Step 4: Commit**
```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "android: VIEW (heartbeat://add) + SEND (text/plain) intent-filters (T5)"
```

---

## Phase F3 — Outbound shares

### Task 6: "Share contact" on My Profile

**Files:** Modify `lib/features/identity/identity_screen.dart` (after the "Copy hex" button ≈ line 144)

- [x] **Step 1: Read** the Copy-hex button area; confirm `widget.pubkeyHex` (self pubkey) and `_initial` (loaded display name) are in scope, and add imports `package:share_plus/share_plus.dart` + `../contacts/contact_link.dart`.

- [x] **Step 2: Add the button** directly below the Copy-hex button:
```dart
const SizedBox(height: 8),
OutlinedButton.icon(
  onPressed: () async {
    final uri = ContactLink(widget.pubkeyHex, _initial).toUri();
    await Share.share('Add me on heart•beat: $uri',
        subject: 'My heart•beat contact');
  },
  icon: const Icon(Icons.ios_share),
  label: const Text('Share contact'),
),
```
(Use the real display-name field name found in step 1 if it's not `_initial`.)

- [x] **Step 3: Verify**

Run: `flutter analyze lib/features/identity/identity_screen.dart` → no new issues; `flutter build apk --debug` succeeds.

- [x] **Step 4: Commit**
```bash
git add lib/features/identity/identity_screen.dart
git commit -m "profile: Share contact button (share my add-link) (T6)"
```

### Task 7: `shareContact` helper + "Share contact" in the header sheet

**Files:**
- Modify: `lib/features/contacts/contact_actions.dart` (add helper)
- Modify: `lib/features/chat/chat_thread_screen.dart` (header bottom sheet ≈ line 332, alongside Rename/Delete)

- [x] **Step 1: Add the helper** to `contact_actions.dart` (imports `package:share_plus/share_plus.dart`, `../../util/display_name.dart`, `contact_link.dart`, and the `Contact` model already imported):
```dart
/// Shares an add-link for [contact] via the OS share sheet. No dialog — goes
/// straight to the system chooser (which includes heart•beat itself).
Future<void> shareContact(BuildContext context, model.Contact contact) async {
  final name = resolveName(contact.pubkeyHex, contact);
  final uri = ContactLink(contact.pubkeyHex, name).toUri();
  await Share.share('Add $name on heart•beat: $uri');
}
```
(Match the file's existing `model.Contact` import alias; if it imports `Contact` unaliased, use that.)

- [x] **Step 2: Add "Share contact" to the header sheet** — in `chat_thread_screen.dart`'s `showModalBottomSheet` (≈ line 332), add a `ListTile` above Rename:
```dart
ListTile(
  leading: const Icon(Icons.ios_share),
  title: const Text('Share contact'),
  onTap: () async {
    Navigator.of(sheetContext).pop();
    await shareContact(context, contact);
  },
),
```
Use the sheet's actual context variable + the `contact` in scope there (read the surrounding code). Import `../contacts/contact_actions.dart` if not already.

- [x] **Step 3: Verify**

Run: `flutter analyze` → no new issues; `flutter build apk --debug` succeeds.

- [x] **Step 4: Commit**
```bash
git add lib/features/contacts/contact_actions.dart lib/features/chat/chat_thread_screen.dart
git commit -m "contacts: Share contact action in the header sheet (T7)"
```

---

## Phase F4 — Prefilled Add-Contact + incoming deep link

### Task 8: AddContactScreen prefill (`initialHex` / `initialName`)

**Files:**
- Modify: `lib/features/contacts/add_contact_screen.dart`
- Test: `test/features/contacts/add_contact_prefill_test.dart`

- [x] **Step 1: Write the failing widget test**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_v3/features/contacts/add_contact_screen.dart';

void main() {
  const hex = '116d49edaaee117f9f048fc1803b272412e3103dbd1f98971d5a77cb24e8c19b';

  testWidgets('opens at paste stage prefilled when initialHex/Name given', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: AddContactScreen(initialHex: hex, initialName: 'alice'),
      ),
    ));
    await t.pumpAndSettle();
    // Paste stage fields are populated.
    expect(find.text('alice'), findsWidgets);        // nickname prefilled
    expect(find.textContaining('116d49ed'), findsWidgets); // pubkey prefilled
    expect(find.text('Save contact'), findsOneWidget);     // on the paste stage
  });
}
```
(Adapt finders to the real widget labels if different — read the paste-stage widgets first.)

- [x] **Step 2: Run, confirm FAIL** (constructor doesn't accept the args)

Run: `flutter test test/features/contacts/add_contact_prefill_test.dart`
Expected: FAIL.

- [x] **Step 3: Implement** — change the constructor + add `initState` prefill:
```dart
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key, this.initialHex, this.initialName});
  final String? initialHex;
  final String? initialName;
  ...
}
```
In `_AddContactScreenState`, add `initState`:
```dart
@override
void initState() {
  super.initState();
  if (widget.initialHex != null && widget.initialHex!.isNotEmpty) {
    _pasteCtrl.text = widget.initialHex!;
    _nicknameCtrl.text = widget.initialName ?? '';
    _stage = _Stage.pasteHex;
  }
}
```
(`_stage` defaults to `_Stage.chooseMethod`; setting it here makes the prefilled deep-link land straight on the paste form. Don't break the no-arg path.)

- [x] **Step 4: Run, confirm PASS**

Run: `flutter test test/features/contacts/add_contact_prefill_test.dart` then full `flutter test`.

- [x] **Step 5: Commit**
```bash
git add lib/features/contacts/add_contact_screen.dart test/features/contacts/add_contact_prefill_test.dart
git commit -m "contacts: AddContactScreen initialHex/initialName prefill (T8)"
```

### Task 9: Incoming `heartbeat://add` deep link (cold + warm)

**Files:** Modify `lib/main.dart`

- [x] **Step 1: Read** `lib/main.dart` — the `rootNavigatorKey`, `_openChatThread`, `StartupRouter`, the `coldLaunchChatId` plumbing into `HeartbeatV3App`, and the `/chats` named route. This is the pattern to mirror.

- [x] **Step 2: Cold-launch read** — in `main()` before `runApp`, after the existing notification launch-payload read, add (import `package:app_links/app_links.dart` + `features/contacts/contact_link.dart`):
```dart
ContactLink? coldLaunchContact;
try {
  final initialUri = await AppLinks().getInitialLink();
  if (initialUri != null) coldLaunchContact = ContactLink.parse(initialUri);
} catch (_) {/* no deep link */}
```
Thread `coldLaunchContact` into `HeartbeatV3App` (a new field) the same way `coldLaunchChatId` is threaded, and into `StartupRouter`.

- [x] **Step 3: Cold-launch route** — in `StartupRouter`, after the display-name gate and the `pushReplacementNamed('/chats')`, if `coldLaunchContact != null`, also:
```dart
nav.push(MaterialPageRoute(
  builder: (_) => AddContactScreen(
    initialHex: coldLaunchContact!.pubkeyHex,
    initialName: coldLaunchContact!.name,
  ),
));
```
(Import `features/contacts/add_contact_screen.dart`. Mirror exactly how the existing `coldLaunchChatId` push is done.)

- [x] **Step 4: Warm-link listener** — in `_HeartbeatV3AppState.initState` (where the lifecycle observer is added), subscribe once:
```dart
_linkSub = AppLinks().uriLinkStream.listen((uri) {
  final c = ContactLink.parse(uri);
  if (c == null) return;
  rootNavigatorKey.currentState?.push(MaterialPageRoute(
    builder: (_) => AddContactScreen(initialHex: c.pubkeyHex, initialName: c.name),
  ));
});
```
Store `StreamSubscription? _linkSub;` and cancel it in `dispose`. (Confirm the exact AppLinks API names against the resolved version — v6 exposes `getInitialLink()` and `uriLinkStream`; if the resolved version differs, e.g. `uriLinkStream` vs `allUriLinkStream`, use the resolved one.)

- [x] **Step 5: Verify**

Run: `flutter analyze` clean; `flutter build apk --debug` succeeds.

- [x] **Step 6: Commit**
```bash
git add lib/main.dart
git commit -m "deeplink: route heartbeat://add to prefilled AddContactScreen (cold+warm) (T9)"
```

---

## Phase F5 — Receive-share "forward mode"

### Task 10: Pending-share provider + ChatThreadScreen composer prefill

**Files:**
- Create: `lib/features/sharing/pending_share_provider.dart`
- Modify: `lib/features/chat/chat_thread_screen.dart`

- [x] **Step 1: Create the provider**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text the user shared INTO heart•beat (ACTION_SEND), awaiting forward to a
/// chosen chat. Null when not forwarding. Set by the receive-share handler,
/// cleared when a chat is picked or the user cancels.
final pendingShareTextProvider = StateProvider<String?>((_) => null);
```

- [x] **Step 2: Add `initialComposerText` to ChatThreadScreen** — read the screen's constructor + the composer's `TextEditingController` setup. Add `final String? initialComposerText;` to the constructor, and seed the controller once on first build/init:
```dart
// in initState (or where the composer controller is created):
if (widget.initialComposerText != null && widget.initialComposerText!.isNotEmpty) {
  _composerController.text = widget.initialComposerText!;  // use the real controller name
}
```
(Find the real composer controller — it may live in `Composer`/`composer.dart`; if the controller is owned by a child widget, pass `initialComposerText` down to it. Read `lib/features/chat/composer.dart`.)

- [x] **Step 3: Verify** `flutter analyze` clean; `flutter test` green.

- [x] **Step 4: Commit**
```bash
git add lib/features/sharing/pending_share_provider.dart lib/features/chat/chat_thread_screen.dart lib/features/chat/composer.dart
git commit -m "sharing: pendingShareTextProvider + ChatThreadScreen composer prefill (T10)"
```

### Task 11: ChatListScreen forward mode

**Files:**
- Modify: `lib/features/chat/chat_list_screen.dart`
- Test: `test/features/chat/forward_mode_test.dart`

- [x] **Step 1: Write the failing widget test** — when `pendingShareTextProvider` is set, the list shows a forward banner; tapping a chat navigates with the text and clears the provider. (Read `chat_list_screen.dart` for the real tile widget + a way to seed one chat in a test, mirroring any existing chat_list widget test; if seeding a chat is heavy, at minimum assert the banner appears when the provider is set and disappears when cleared.)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_v3/features/sharing/pending_share_provider.dart';
import 'package:app_v3/features/chat/chat_list_screen.dart';

void main() {
  testWidgets('forward banner shows when pendingShareText is set', (t) async {
    final container = ProviderContainer();
    container.read(pendingShareTextProvider.notifier).state = 'Add bob: https://…';
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatListScreen()),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('Select a chat to forward'), findsOneWidget);
  });
}
```
(Adapt to the real ChatListScreen construction + any required provider overrides so it builds in a test.)

- [x] **Step 2: Run, confirm FAIL.**

- [x] **Step 3: Implement** — in `ChatListScreen.build`, read `final forwarding = ref.watch(pendingShareTextProvider);`. When non-null, render a banner above the list:
```dart
if (forwarding != null)
  Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      leading: const Icon(Icons.forward),
      title: const Text('Select a chat to forward to'),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => ref.read(pendingShareTextProvider.notifier).state = null,
      ),
    ),
  ),
```
And in the chat-tile `onTap`, when `forwarding != null`, navigate to the thread with the text + clear:
```dart
onTap: () {
  final fwd = ref.read(pendingShareTextProvider);
  if (fwd != null) {
    ref.read(pendingShareTextProvider.notifier).state = null;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatThreadScreen(chatId: <thisChatId>, initialComposerText: fwd),
    ));
    return;
  }
  // ...existing open-thread behavior...
},
```
(Apply to BOTH direct and group tile taps; use the real navigation the screen already uses.)

- [x] **Step 4: Run, confirm PASS** then full `flutter test`.

- [x] **Step 5: Commit**
```bash
git add lib/features/chat/chat_list_screen.dart test/features/chat/forward_mode_test.dart
git commit -m "sharing: ChatListScreen forward mode (banner + tap-to-forward) (T11)"
```

### Task 12: Wire `receive_sharing_intent` (cold + warm)

**Files:** Modify `lib/main.dart`

- [x] **Step 1: Cold-launch read** — in `main()` before `runApp`, read the initial shared text (import `package:receive_sharing_intent/receive_sharing_intent.dart`):
```dart
String? coldLaunchShareText;
try {
  final media = await ReceiveSharingIntent.instance.getInitialMedia();
  final txt = media.where((m) => m.type == SharedMediaType.text)
      .map((m) => m.path).where((s) => s.isNotEmpty).join('\n');
  if (txt.isNotEmpty) coldLaunchShareText = txt;
} catch (_) {/* none */}
```
(Confirm the resolved `receive_sharing_intent` API — across versions text arrives via `getInitialMedia()` with `SharedMediaType.text` and the text in `.path`, OR an older `getInitialText()`. Use whatever the resolved version exposes.)

- [x] **Step 2: Seed the provider on cold launch** — thread `coldLaunchShareText` into the app and, after the first frame / in `StartupRouter`, set `pendingShareTextProvider` so Chats-home opens in forward mode:
```dart
if (coldLaunchShareText != null) {
  ref.read(pendingShareTextProvider.notifier).state = coldLaunchShareText;
}
```
(Cold launch already lands on `/chats`; the banner appears because the provider is set. Reset `getInitialMedia` per the plugin's "call once" guidance — call `ReceiveSharingIntent.instance.reset()` after reading if the resolved version requires it.)

- [x] **Step 3: Warm listener** — in `_HeartbeatV3AppState.initState`, subscribe to the media stream; on text, set the provider + ensure Chats-home is foregrounded:
```dart
_shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((media) {
  final txt = media.where((m) => m.type == SharedMediaType.text)
      .map((m) => m.path).where((s) => s.isNotEmpty).join('\n');
  if (txt.isEmpty) return;
  ref.read(pendingShareTextProvider.notifier).state = txt;
  rootNavigatorKey.currentState?.popUntil((r) => r.isFirst); // back to Chats home
});
```
Store + cancel `_shareSub` in dispose. (`ref` access in `main.dart`'s app state — use the existing `ref` the lifecycle code already uses, e.g. via `ProviderScope`/`ConsumerState`.)

- [x] **Step 4: Verify**

Run: `flutter analyze` clean; `flutter build apk --debug` succeeds (this confirms both share plugins compile together — watch for the plugin-coexistence note in the spec §5; if the manifest SEND filter conflicts with app_links, gate by intent action).

- [x] **Step 5: Commit**
```bash
git add lib/main.dart
git commit -m "sharing: receive_sharing_intent -> forward mode on Chats home (cold+warm) (T12)"
```

---

## Phase F6 — Verify + wrap

### Task 13: Device verification + version

**Files:** none (verify) + `pubspec.yaml` (version)

- [x] **Step 1: Quality gates** — `flutter test` (all green incl. new ContactLink/prefill/forward tests), `flutter analyze` (clean apart from the pre-existing `hex_codec` info), `flutter build apk --debug` (succeeds).

- [x] **Step 2: Two-emulator manual verify** (use the `heart-beat-v3-deploy` loop; boot 2 emulators — NOT 3, per the host limit in `mem:presence-campaign-state`):
  - **F1:** group with self → member row shows "You".
  - **F2:** My Profile → Share contact → share to the *other* emulator (e.g. via a notes app / direct intent) → tap link → landing page → app opens at prefilled Paste → Save adds the sharer. (If cross-app sharing between emulators is awkward, verify the `heartbeat://add?k=&n=` intent directly: `adb -s <emu> shell am start -a android.intent.action.VIEW -d "heartbeat://add?k=<hex>&n=test"` → app opens prefilled.)
  - **F3a:** contact header sheet → Share contact → OS sheet shows the link.
  - **F3b:** share text into heart•beat (`adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "hello"` targeting the app) → lands on Chats home forward banner → tap a chat → composer prefilled → Send delivers.
  - **Not-installed fallback:** open the https link in a browser on a device without the app → Play Store (tester account) or the landing page's manual-code instructions.
  Capture screenshots; log any failures.

- [x] **Step 3: Bump version** in `pubspec.yaml` (e.g. `1.2.0+12`).

- [x] **Step 4: Commit + (optionally) tag/push** — ask the user before tagging/pushing (release action).
```bash
git add pubspec.yaml
git commit -m "release: contact sharing + deep links (T13)"
```

---

## Self-review

- **Spec coverage:** "You" (T1) ✓; ContactLink (T3) ✓; landing page (T4) ✓; manifest VIEW+SEND (T5) ✓; deps (T2) ✓; share-my-contact (T6) ✓; share-a-contact + header sheet (T7) ✓; AddContact prefill (T8) ✓; incoming deep-link cold+warm (T9) ✓; pending-share provider + composer prefill (T10) ✓; forward mode (T11) ✓; receive-share wiring (T12) ✓; verify/version (T13) ✓. Error handling (invalid k → parse null → ignored) covered in T3 + T9. Play-Store-tester caveat noted in spec.
- **Type consistency:** `ContactLink(pubkeyHex, name)` / `.toUri()` / `.parse(Uri)`; `AddContactScreen(initialHex, initialName)`; `ChatThreadScreen(..., initialComposerText)`; `pendingShareTextProvider` (StateProvider<String?>); `shareContact(context, contact)` — used consistently across tasks.
- **Implementer must confirm against real code (flagged at point of use):** the group-settings member/creator lines; `identity_screen` display-name field name; the `chat_thread_screen` header-sheet context + `contact` variable; the composer's real `TextEditingController` (possibly in `composer.dart`); `main.dart`'s `coldLaunchChatId` threading + `StartupRouter`; the exact `app_links` and `receive_sharing_intent` APIs of the resolved versions; the chat-tile `onTap` sites (direct + group). Native intent flows (T5/T9/T12) are config + manual-verify, not unit-testable.
- **Plugin-coexistence risk (T12):** `app_links` (VIEW) + `receive_sharing_intent` (SEND) handle different actions; if a launch-intent conflict surfaces, gate by intent action or use a single native MethodChannel.

---

## As-built notes & deviations (post-implementation, 2026-06-01)

Shipped at `v1.2.0+12`, tag `v1.2.0-contact-sharing`. Resolved dep versions: `share_plus 10.1.4`, `app_links 6.4.1` (v6 API: `getInitialLink()` / `uriLinkStream`), `receive_sharing_intent 1.8.1` (`getInitialMedia()` / `getMediaStream()`, `SharedMediaType.text`, payload in `.path`, plus `reset()`). `share_plus 10.1.4`'s static `Share.share(...)` is NOT deprecated — used as-is. Real call sites confirmed: identity self-pubkey `widget.pubkeyHex` + name `_initial`; `contact_actions.dart` imports `Contact` as `model.Contact`; header sheet context var `sheetCtx`, contact var `peerContact`; composer controller `_controller` lives in `composer.dart` (`_ComposerState`), not the screen; chat tiles `_buildDirectTile` + `_buildGroupTile` both route through a shared `_openThread(context, ref)`.

**Deviations from the plan's reference code (all necessary, all committed):**
- **`ContactLink.toUri()` encodes with `%20`, not the plan's `Uri.replace(queryParameters:)`.** `Uri.replace` encodes spaces as `+`, which failed the `n=Al%20Ice` test assertion. Final impl builds the URL via `Uri.encodeComponent` + string concat. Behaviorally equivalent; `%20` is more universally compatible. (`529dbc6`, `abc2f6e`.)
- **`android/build.gradle.kts` gained a JVM-17 hook (T5).** `receive_sharing_intent` (and other plugins) introduced a Java 1.8 vs Kotlin 21 target mismatch that broke `flutter build apk`. Fixed with a `gradle.afterProject` block forcing `JavaVersion.VERSION_17` / `JvmTarget.JVM_17` across non-app subprojects. Bundled into the T5 commit (`2f78dbe`).

**Review fixes (per the planned cadence — T9/T11/T12 + one combined review):**
- **T9 (`49caee9`):** the cold-launch `getInitialLink()` catch logged the error instead of silently swallowing it, matching the file's other catch blocks.
- **T11 (`d3a42ab`):** Android back button now clears `pendingShareTextProvider` (via `PopScope`) so forward mode can't get stranded; added a dismiss-path widget test.
- **T12 (`2ec0777`):** `ReceiveSharingIntent.reset()` moved into a `finally` (so stale initial media can't ghost-trigger forward mode on a later cold launch); added a `mounted` guard before `ref.read` in the warm `getMediaStream()` listener.
- **Combined review (`fab3001`):** fixed a **stuck-banner bug** — the "new conversation" FAB (→ `SelectContactScreen` / `NewGroupScreen`) bypassed the forward read-and-clear, leaving the banner stranded. The FAB is now hidden while forwarding. Added a regression test. (Round-trip link encoding — `toUri` → landing `intent://` → manifest VIEW → `parse` — was verified end-to-end as sound.)

**Post-release fix — landing-page UA detection (`598ed21`, deployed to Pages):**
On-device verification surfaced that the link opened the app on the phone but bounced to the Play Store on a Lenovo tablet. Root cause: the tablet's Chrome runs in **desktop-site mode**, so its UA is a plain desktop Linux string (`X11; Linux x86_64`, no "Android"). The page's `/android/i.test(navigator.userAgent)` was false → button pointed at the Play Store and the `intent://` never fired. Fixed `docs/add/index.html` to detect Android via multiple signals: UA string, UA-Client-Hints `platform`, OR touch-capable Linux/X11 that isn't ChromeOS/Windows/Mac (a desktop-mode Android tablet). Genuine desktops still fall through to the Play Store. Verified on the actual tablet: the link now auto-launches the app to the prefilled Add-Contact page (name + pubkey, Save enabled).

**Manual device verification:** owner-run (single host can't keep enough emulators stable). The app-side deep link was confirmed live on the tablet via `adb am start -a VIEW -d "heartbeat://add?k=…&n=…"` (opens prefilled) and via the full browser → landing-page → app flow after the UA fix.

**Caveat unchanged:** the Play-Store fallback only resolves for enrolled testers until a public Play track is published (Internal Testing only). And an in-app browser/webview (vs Chrome) may still ignore `intent://` — opening in Chrome is the robust path.
