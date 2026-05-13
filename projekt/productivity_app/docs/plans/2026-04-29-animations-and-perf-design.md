# Light animations + perf pass

**Date:** 2026-04-29
**Branch:** feat/habits

## Goal

Add lightweight animations that fit the neobrutalism aesthetic and tighten three perf hotspots — without UX changes for the perf items.

## Scope (6 items)

### Animations

**A1 — NeoPressable wrapper**
New widget `lib/widgets/neo_pressable.dart`. Wraps a child + handles `onTap`. On `onTapDown`, child translates by `NeoTheme.shadowOffset` and the surrounding shadow flattens. 120ms `Curves.easeOut`. Applied to: FAB (calendar, habits), confirm button in `TaskCard`, primary `ElevatedButton`s in dialogs. `IconButton`s keep their default ripple.

**A2 — Animated XP bar**
In `xp_bar.dart` wrap `FractionallySizedBox` in `TweenAnimationBuilder<double>` (600ms, `Curves.easeOutCubic`) so the bar animates to the new progress value when XP changes.

**A5 — Task complete pulse**
In `TaskCard`, single `AnimationController` driven by `didUpdateWidget`. Trigger when `completed` flips false → true. 500ms: scale 1.0 → 1.04 → 1.0 + green-flash overlay (alpha 0.3 → 0). Skip when card mounts already-completed.

### Performance

**O1 — Service singletons**
`TaskService`, `HabitService`, `UserService` get a `factory` constructor returning a cached instance:
```dart
factory TaskService() => _instance ??= TaskService._();
static TaskService? _instance;
TaskService._();
```
Pages keep calling `TaskService()` — same surface, fewer instances.

**O2 — Cache decoded image in TaskCard**
`_TaskCardState` stores `Uint8List? _decodedImage` keyed by the source base64. Decode in `initState` and `didUpdateWidget` only when source changes. `Image.memory` reads from the cached bytes.

**O3 — Hoist unread-count stream**
Move the `unreadNotificationCount()` `StreamBuilder` out of `_buildActions`. State holds `int _unreadCount = 0`; `StreamSubscription` in `initState`, cancel in `dispose`. `_buildActions` becomes pure-function-ish.

## Out of scope

A3, A4, A6, A7 from the menu. O4 (Firestore query optimization for calendar markers) deferred — needs more investigation.

## Testing

- `xp_bar_test.dart` — extend to assert intermediate animated values.
- `flutter analyze` clean.
- Manual smoke: calendar add/edit/complete task, habits page, dark + light theme, narrow + wide layout.

## Risk

- Singleton change breaks tests that injected per-page services. Verified: no current test does this — all tests are pure model/util unit tests.
- A5 must not pulse on mount-with-completed (would fire on every revisit). `didUpdateWidget` transition check handles this.
