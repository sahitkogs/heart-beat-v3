# Contact Sharing + Deep Links — Design

> **Status:** approved 2026-06-01. Spec for the next implementation cycle.
> **Repo:** `heart-beat-v3` (Flutter client) + a static landing page on the existing GitHub Pages (`docs/`).

## 1. Goal

Three user-facing features, built on one shared deep-link foundation:

1. **"You" in group settings** — the current user's own member row reads "You", not their name.
2. **Share my contact** (My Profile) — a button that shares an "add me" link to any app (WhatsApp, …). The recipient taps it → heart•beat opens to the **Paste-hex screen prefilled** with name + key → "Save contact". If heart•beat isn't installed → Play Store.
3. **Share a contact** (the contact action bottom-sheet) — a "Share contact" option beside Rename/Delete that shares **that contact's** link. heart•beat also appears as a **share target**: sharing into it opens the **Chats home in "forward mode"** → pick a chat → the composer is prefilled with the shared text → Send.

## 2. Scope

**In:** the shared `ContactLink` format + helper; a static landing page on Pages; Android manifest intent-filters; three deps (`share_plus`, `app_links`, `receive_sharing_intent`); the three features above; cold + warm routing for incoming deep links and shared text; `AddContactScreen` prefill, `ChatThreadScreen` composer prefill, `ChatListScreen` forward mode.

**Out (this cycle):** iOS (Android-only — applicationId `com.sahitkogs.heartbeat`, Play-only release); verified App Links (`assetlinks.json` — avoided by the landing-page approach); sending a structured "contact card" message type (we forward the link as **plain text**); QR-format change (the on-screen QR stays bare 64-hex; the *link* carries the name).

## 3. The shared link — `ContactLink`

**Format:** `https://sahitkogs.github.io/heart-beat-v3/add/?k=<64-char lowercase hex>&n=<URL-encoded display name>`
- `k` is required (Ed25519 pubkey hex). `n` is optional (the sharer's/contact's resolved name).

**New unit — `lib/features/contacts/contact_link.dart`** (the single testable core, used by every outbound share and the inbound handler):
```dart
class ContactLink {
  final String pubkeyHex;
  final String? name;
  const ContactLink(this.pubkeyHex, this.name);

  static const _base = 'https://sahitkogs.github.io/heart-beat-v3/add/';

  /// Build the shareable https URL.
  Uri toUri() => Uri.parse(_base).replace(queryParameters: {
        'k': pubkeyHex,
        if (name != null && name!.isNotEmpty) 'n': name!,
      });

  /// Parse either the https landing URL OR the heartbeat://add deep link.
  /// Returns null if there's no valid 64-hex `k`. Reuses ScanHandler-grade
  /// validation on the pubkey.
  static ContactLink? parse(Uri uri) { /* read k + n, validate k is 64-hex */ }
}
```
Both the https URL (`…/add/?k=&n=`) and the deep link (`heartbeat://add?k=&n=`) carry the same `k`/`n` query params, so `parse` handles both.

## 4. Landing page — `docs/add/index.html`

Served at `https://sahitkogs.github.io/heart-beat-v3/add/` (Pages already serves `main:/docs`). On load it:
1. Reads `k` + `n` from `location.search`.
2. Renders a minimal branded page: "Add **\<name\>** on heart•beat" + an "Open in heart•beat" button.
3. Immediately (and on button tap) navigates to the Android intent URL:
   ```
   intent://add?k=<k>&n=<n>#Intent;scheme=heartbeat;package=com.sahitkogs.heartbeat;S.browser_fallback_url=https%3A%2F%2Fplay.google.com%2Fstore%2Fapps%2Fdetails%3Fid%3Dcom.sahitkogs.heartbeat;end
   ```
   → app installed: opens via the `heartbeat://add?...` VIEW intent. → not installed: Android follows `browser_fallback_url` to the Play listing.
4. Non-Android (desktop/iOS): no auto-redirect; show the pubkey hex + a "copy this code into heart•beat → Add contact → Paste hex" instruction (graceful, no dead-end).

**Caveat (documented, non-blocking):** the Play listing is Internal-Testing-only today, so the fallback resolves only for enrolled testers until a public track is published.

## 5. Android manifest + deps

`android/app/src/main/AndroidManifest.xml` — add two intent-filters to the existing MainActivity `<activity>` (which currently has only MAIN/LAUNCHER):
```xml
<!-- Incoming add-contact deep link (from the landing page) -->
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

**Deps (`pubspec.yaml`):** `share_plus` (outbound OS share sheet), `app_links` (incoming `VIEW` / `heartbeat://`), `receive_sharing_intent` (incoming `SEND` text → share target).

**Plugin-coexistence note (verify in impl):** `app_links` consumes `VIEW` intents; `receive_sharing_intent` consumes `SEND` intents — different actions, so a given launch delivers to exactly one. On cold start each reads only its own initial intent; if a conflict surfaces (both reading the launch intent), gate by intent action or fall back to a single native `MethodChannel` in `MainActivity`.

## 6. Feature 1 — "You" in group settings

`lib/features/chat/group_settings_screen.dart`:
- The member label is `resolveName(member.memberPubkeyHex, contact)` with a separate `_Badge(label: 'you')` when `memberIsMe` (≈ lines 201–211). Change: when `memberIsMe`, the label **is** `'You'` and the redundant `'you'` badge is dropped.
- The header creator self-reference (`creator == me ? 'you' : …`, ≈ line 129) → `'You'` for consistency.
- No other behavior changes.

## 7. Feature 2 — Share my contact (My Profile)

`lib/features/identity/identity_screen.dart`, after the "Copy hex" button (≈ line 144): add a "Share contact" `OutlinedButton.icon` (share icon). On tap:
```dart
final name = _initial; // the user's loaded display name (already in state)
final uri = ContactLink(widget.pubkeyHex, name).toUri();
await Share.share('Add me on heart•beat: $uri', subject: 'My heart•beat contact');
```
The OS share sheet opens; the user picks any app. (Self pubkey = `widget.pubkeyHex`; display name already loaded as `_initial`.)

## 8. Feature 3a — Share a contact (action bottom-sheet)

The bottom-sheet that lists **Rename / Delete** (opened from the chat-thread header tap per T13.UX.8, and reachable from the contacts 3-dot menu). The plan must **locate the exact `showModalBottomSheet`** that renders those options and add a **"Share contact"** row (share icon) above/with them. On tap:
```dart
final uri = ContactLink(contact.pubkeyHex, resolveName(contact.pubkeyHex, contact)).toUri();
await Share.share('Add ${resolveName(...)} on heart•beat: $uri');
```
The dialog helpers in `lib/features/contacts/contact_actions.dart` are the model for a new `shareContact(context, contact)` helper; the share itself needs no dialog (straight to the OS sheet).

## 9. Feature 3b — heart•beat as a share target ("forward mode")

When the app receives shared **text** (`ACTION_SEND`, via `receive_sharing_intent`):
1. The app opens (or resumes) and lands on **Chats home** with a pending-share payload.
2. A **`pendingShareTextProvider`** (a simple `StateProvider<String?>`) holds the shared text.
3. `ChatListScreen` enters **forward mode** when that provider is non-null: a top banner "Select a chat to forward to" (+ a cancel ✕ that clears the provider).
4. Tapping any chat tile in forward mode opens `ChatThreadScreen(chatId, initialComposerText: <shared text>)` and clears the pending-share provider.
5. `ChatThreadScreen` accepts an optional `initialComposerText` that pre-fills the composer `TextEditingController` on first build; the user reviews and taps **Send** (normal send path — the shared text is just a normal outgoing text message).

This means a forwarded "contact link" is delivered as a **plain-text message**; the recipient taps the link → the landing page → adds that contact. No new message type.

## 10. Routing (incoming)

Mirrors the existing notification cold-launch pattern (`rootNavigatorKey`, `StartupRouter`, `coldLaunchChatId` in `lib/main.dart`).

**`heartbeat://add?k=&n=` (deep link, via `app_links`):**
- **Cold launch:** `main()` reads `AppLinks().getInitialAppLink()` before `runApp`, passes the parsed `ContactLink` into `HeartbeatV3App` → `StartupRouter`. After the display-name gate, route: `…/chats` then `push(AddContactScreen(initialHex, initialName))`.
- **Warm:** an `AppLinks().uriLinkStream` listener (registered once, e.g. in `_HeartbeatV3AppState`) pushes `AddContactScreen(initialHex, initialName)` on `rootNavigatorKey`.
- Invalid/missing `k` → ignore (or land on Add-contact chooser); never crash.

**`ACTION_SEND` text (via `receive_sharing_intent`):**
- **Cold launch:** read initial shared text before `runApp`; set `pendingShareTextProvider`; `StartupRouter` lands on `…/chats` (forward mode shows because the provider is set).
- **Warm:** stream listener sets `pendingShareTextProvider` and ensures Chats home is foregrounded.

## 11. Screen changes

- **`AddContactScreen`** (`lib/features/contacts/add_contact_screen.dart`): constructor gains `String? initialHex, String? initialName`. In `initState`, if `initialHex` is present: set `_pasteCtrl.text = initialHex`, `_nicknameCtrl.text = initialName ?? ''`, and start at `_Stage.pasteHex` (prefilled; the user taps **Save contact**). Existing validation (`ScanHandler.parse`) and `_saveAndAdvance` are unchanged.
- **`ChatThreadScreen`** (`lib/features/chat/chat_thread_screen.dart`): constructor gains optional `String? initialComposerText`; the composer controller is seeded with it on first build only.
- **`ChatListScreen`** (`lib/features/chat/chat_list_screen.dart`): forward-mode banner + tap-to-forward behavior gated on `pendingShareTextProvider`.

## 12. Error handling & edge cases

- **Invalid `k`** in a link → `ContactLink.parse` returns null → routing ignores it (Add-contact opens to the method chooser, or nothing). The paste form still validates on Save.
- **Name with odd characters / very long** → URL-encoded in the link; on the receiving side the prefilled nickname is editable (and the 40-char limit still applies on Save).
- **Sharing into heart•beat while a chat is open** → still routes to Chats-home forward mode (consistent entry point); cancel ✕ returns to normal.
- **Self-link** (you tap your own share link) → AddContactScreen prefilled with your own pubkey; Save would add yourself — acceptable edge (or optionally detect self and no-op; treat as low priority).
- **Plugin double-handling a launch intent** → gate by intent action (see §5).

## 13. Testing

**Unit (TDD):**
- `ContactLink`: `toUri` round-trips; `parse` accepts the https URL and the `heartbeat://` deep link, extracts `k`+`n`, rejects non-64-hex `k`, handles missing `n`, URL-decodes `n`.
- `AddContactScreen` prefill: given `initialHex`/`initialName`, opens at the paste stage with both fields populated and Save enabled (widget test).
- Forward mode: `pendingShareTextProvider` set → `ChatListScreen` shows the banner; tapping a chat navigates with `initialComposerText` and clears the provider (widget test).

**Manual on emulators** (can't be unit-tested — cross-app intents): share-my-contact → tap link on a 2nd emulator → app opens prefilled → Save; share-a-contact → pick heart•beat → forward mode → send; not-installed → Play Store (tester account); landing page renders on desktop.

Keep `flutter test` green, `flutter analyze` clean, APK builds.

## 14. Acceptance criteria

- [ ] Group settings shows "You" for the current user (no name, no redundant badge); creator header self-ref says "You".
- [ ] My Profile "Share contact" opens the OS share sheet with a working `…/add/?k=&n=` link; tapping it on a device **with** the app opens the prefilled Paste screen → Save adds the sharer; **without** the app → Play Store.
- [ ] Contact action sheet has "Share contact" that shares that contact's link.
- [ ] heart•beat appears as a share target for text; sharing into it lands on Chats home in forward mode → picking a chat prefills the composer → Send delivers the text.
- [ ] `ContactLink` + prefill + forward-mode unit/widget tests pass; suite green; analyze clean; APK builds.
- [ ] Landing page committed under `docs/add/` and live on Pages.

## 15. Follow-ups (not this cycle)
- Verified App Links (`assetlinks.json`) once a custom domain or root Pages repo exists — removes the landing-page hop.
- A structured "contact card" message type (instead of forwarding a plain-text link).
- Detect and special-case self-link.
- iOS Universal Links + share extension if/when an iOS build ships.
