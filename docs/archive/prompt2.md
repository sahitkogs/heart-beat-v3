---
Implement Phase 10.4.3b (client receipts + outbox + ticks) for heart-beat-v3.
Execute the plan inline, task-by-task, with checkpoints for review.

Plan:    C:\Users\Lambda\Documents\heart-beat-v3\docs\2026-05-26-client-receipts-implementation-plan.md
Spec (for cross-reference):
         C:\Users\Lambda\Documents\heart-beat-v3\docs\2026-05-26-message-delivery-guarantees-design.md §5 / §7 / §10
Roadmap row: C:\Users\Lambda\Documents\heart-beat\docs\heartbeat-roadmap.md — Phase 10.4.3 (status "10.4.3a shipped 2026-05-26 / 10.4.3b plan pending")

Use the superpowers:executing-plans skill. Batch sensibly with four checkpoints where I review before continuing:
  - After Task 5  (Drift schema v6→v7 done, OutboxDao + ChatsDao helpers done, both envelope changes done — wire protocol is locked)
  - After Task 11 (Both Layer B helpers — DeliveryReceiptDebouncer + OutboxRetransmitter — exist and are unit-tested; MessageService changes through Task 9 done)
  - After Task 15 (Lifecycle wiring + tick UI + read-trigger + forgetPeer cascade all in — feature is behaviorally complete; only verify + tag remain)
  - After Task 17 (Two-phone E2E results captured in testing-session-results-2026-05-26-10.4.3b.md — pause before tagging so I can decide when to push + Play upload)

Conventions for this work:
  - Linear history on main in heart-beat-v3, one commit per task (matches the existing 10.4 / 10.4.1 / 10.4.2 pattern).
  - Commit message format: "<area>: <terse>" with a body explaining why (mirror style of be052f5, 0b0bcf2, and the 10.4.3a commits in heartbeat-server: a60f2f1, 1400e4b, 640a6e6, 7823663).
  - TDD throughout — every code task starts with a failing test.
  - Quality gates per task: `flutter test` must stay green; `flutter analyze` no new warnings; `flutter build apk --debug` clean at the final integration tasks (12, 16).
  - Run `flutter pub run build_runner build --delete-conflicting-outputs` after any Drift schema or @DriftAccessor change before running affected tests.
  - Do NOT run `git push` or upload to Play Console. I'll do those manually after Task 18.
  - Do NOT skip pre-commit hooks. If one fails, fix the underlying issue.

Two adjustments to call out as you go:

  1. Task 3 has a small fix-up commit baked into Step 1 that retroactively edits the Task 1 migration to also add `messages.read_at`. If you've already committed Task 1 by the time you hit Task 3, follow the plan's "single extra addColumn call in a small fixup commit" instruction — don't amend Task 1's commit.

  2. Task 14 Step 3 (`_retrySend`) calls a private `_currentDisplayName` via `svc.` — the plan flags this and instructs you to make it public (`currentDisplayName()`) AND update the `_MessageServiceReceiptSender` adapter from Task 12 to call the public version. Do that as part of Task 14, not as a separate commit.

Target artifact: `heart-beat-v3 v1.0.3-phase10.4.3b` tag at the end of Task 18. I'll push + upload the .aab to Play Internal Testing separately.

Background context the new session needs:
  - This is Phase 2 / Layer B of the 10.4.3 message-delivery-guarantees work. Phase 1 / Layer A (server-side offline queue) shipped 2026-05-26 as `heartbeat-server v0.2.0-offline-queue`, live on 34.42.231.29:8080. `/healthz` exposes `offline_queue_total`. Existing clients (1.0.2+3) benefit from Layer A immediately. This plan adds the sender-side outbox + receipts that give the WhatsApp-style ✓ → ✓✓ → ✓✓ (accent) ticks and close the half-dead-WS race documented as Issue #1 in heart-beat-v3\docs\testing-session-results-2026-05-24.md.
  - The two failure modes this closes are documented as Issue #1 (phantom drop) and Issue #2 (force-stop / FCM-suppressed) in testing-session-results-2026-05-24.md.
  - Drift schema is currently at version 6 (set in `lib/data/app_database.dart:191`). The v5→v6 migration was destructive; v6→v7 in this plan is additive (`addColumn` + `createTable`), so existing installs upgrade in place.
  - The existing `MessageService` is at `lib/chat/message_service.dart` and is ~1520 lines. The send + inbound paths are tightly intertwined with libsignal session lifecycle; the plan's changes are deliberately surgical (no refactor of the bigger flow).
  - The `_unackedByPeer` map at `message_service.dart:79` is removed in Task 9 — the comment block at that line explains why it existed; the wake fallback becomes unconditional because Layer A now handles the durable side.
  - The Flutter app's `applicationId` is `com.sahitkogs.heartbeat` (renamed in 10.4.2). The release track in Play Console is Internal Testing.

---

A couple of small tips for the new session:

- Make sure the Flutter toolchain is on PATH. If `flutter` isn't found, the path is usually `C:\flutter\bin` or `C:\src\flutter\bin` — `Get-Command flutter` to check.
- Working directory should be `C:\Users\Lambda\Documents\heart-beat-v3`. The plan's commands assume that. heart-beat-v3 is its own git repo (separate from heartbeat-server and heart-beat).
- The new session can freely read from heartbeat-server (for cross-reference of the Layer A wire) and heart-beat (for the roadmap), but should only modify heart-beat-v3.
- If you want to feed in even less context, drop the "Background context" block — the plan + spec are self-sufficient. I included it because a cold-start session benefits from knowing why Layer B is being built and what Layer A already does.
