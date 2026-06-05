# New-session kickoff prompt — Contact Sharing + Deep Links

Paste everything in the box below into a fresh Claude Code session started in
`C:\Users\Lambda\Documents\heart-beat-v3`.

---

```
Implement the "Contact Sharing + Deep Links" feature using subagent-driven development.

Plan:  docs/2026-06-01-contact-sharing-plan.md   (13 tasks, 6 phases — execute these)
Spec:  docs/2026-06-01-contact-sharing-design.md  (the approved design / rationale)

Use the superpowers:subagent-driven-development skill to execute the plan task by
task: a fresh implementer subagent per task that does TDD (failing test → implement →
full `flutter test` green → `flutter analyze` clean → commit). Provide each subagent the
full task text from the plan plus the scene-setting context it needs — don't make it read
the plan file.

Conventions / environment:
- Repo on `main`; commit one task at a time (project convention is linear history on main).
  You have my consent to implement on main.
- Flutter isn't on PATH: PowerShell `$env:PATH = "C:\Users\Lambda\flutter\bin;" + $env:PATH`.
  Package name is `app_v3`. App id `com.sahitkogs.heartbeat`. GitHub Pages base is
  `https://sahitkogs.github.io/heart-beat-v3/` (main:/docs).
- There's a `heart-beat-v3-deploy` skill for the build/install/launch/screenshot loop.

Review cadence (important — don't over-review):
- Do NOT run the two-stage spec+quality review after every task. Rely on each task's TDD
  gate (tests green + analyze clean + commit) as the floor.
- Reserve a code-quality review subagent for the RISKY tasks only — T9 (heartbeat:// deep-
  link cold+warm routing), T11 (forward mode), and T12 (receive_sharing_intent wiring) —
  plus one combined review at the end. Fix any findings before moving on.

Things to watch (already flagged in the plan's self-review):
- 3 new deps: share_plus, app_links, receive_sharing_intent. Confirm the resolved versions'
  exact APIs before using them (app_links: getInitialLink()/uriLinkStream;
  receive_sharing_intent: getInitialMedia()/getMediaStream() with SharedMediaType.text — APIs
  drift across versions; adapt to what resolves).
- Plugin coexistence (T12): app_links handles VIEW intents, receive_sharing_intent handles
  SEND — different actions, should coexist; if a launch-intent conflict surfaces, gate by
  intent action or fall back to a single native MethodChannel in MainActivity.
- Several tasks need exact-name confirmation against real code (group-settings member/creator
  lines; identity_screen display-name field; chat_thread header-sheet context + `contact` var;
  the composer's real TextEditingController, possibly in composer.dart; main.dart's
  coldLaunchChatId threading + StartupRouter; chat-tile onTap sites). The implementer subagents
  must read those files first.
- Native intent flows (T5 manifest, T9, T12) are config + manual-verify, not unit-testable.

Live / manual parts (surface these to me when you reach them):
- T13 manual verify uses TWO emulators (NOT three — this host can't keep 3 x86 emulators
  stable; see the presence-campaign-state memory). AVDs: Heartbeat / Heartbeat2 / Heartbeat3,
  android-36 google_apis_playstore, ports 5554/5556/5558.
- The not-installed → Play Store fallback only resolves for enrolled testers until a public
  Play track is published (the app is Internal Testing only today).

At the end: bump the client version (T13), then STOP and ask me before tagging or pushing —
those are release actions I want to approve.

Start with Task 1 (group settings "You") and proceed in plan order.
```

---

### Notes for you (not part of the prompt)
- The plan is fully self-contained; the new session doesn't need this conversation's history.
- Relevant memories will auto-load in the new session: `review-cadence`, `presence-campaign-state` (the 3-emulator host limit + onboarding/pairing tap coords), `presence-server-followup`, and the read-tick color one.
- If you'd rather do it as one or two big batches instead of per-task subagents, swap the second paragraph for "use superpowers:executing-plans" instead.
