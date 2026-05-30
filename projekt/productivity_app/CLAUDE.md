# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run on Chrome (primary dev target)
flutter run -d chrome

# Run on connected device / emulator
flutter run

# Build for web (deployed to Firebase Hosting)
flutter build web

# Deploy to Firebase Hosting (https://calendar-mot.web.app)
firebase deploy --only hosting

# Deploy Firestore rules (after editing firestore.rules)
firebase deploy --only firestore:rules

# Deploy Firestore indexes (after editing firestore.indexes.json)
firebase deploy --only firestore:indexes

# Analyze code
flutter analyze

# Run all tests
flutter test

# Run a single test file / filter by test name
flutter test test/models/habit_test.dart
flutter test --name "expectedOn"
```

## Architecture Overview

**Motivator** — gamified productivity app where users create tasks, attach photo proof, and share them with friends for confirmation. Friends verify tasks via deep links, triggering XP/coin rewards, level-ups, and streak bonuses. Habits generate recurring task instances on a rolling 30-day window. Built with Flutter + Firebase.

### Tech Stack
- **Flutter 3.9+** with Material 3, targeting Web, Android, iOS, Windows, macOS
- **Firebase**: Auth (email/password + Google Sign-In), Cloud Firestore, Hosting
- **State**: Provider (`ThemeProvider` in `main.dart`, persisted via SharedPreferences) + StreamBuilder for Firestore real-time data
- **Navigation**: Named routes in `main.dart` — `/` (Login), `/calendar`, `/confirm`, `/settings`, `/stats`, `/notifications`, `/habits`, `/profile`, `/find-friends`. Query-param routes via `onGenerateRoute`: `/friend?code=X`, `/friend-profile?uid=X` (order-sensitive: `/friend-profile` is matched before `/friend`).
- **Deep linking**: `app_links` package, custom scheme `adamapp://confirm?code=<code>` + `adamapp://friend?code=<code>`, web fragment URLs
- **Charts**: `fl_chart` (stats page)

### Project Structure
- `lib/main.dart` — App entry, `ThemeProvider`, route table, deep link handling, `navigatorKey`, achievement notif-stream listener
- `lib/pages/` — Full-screen pages: login, calendar, confirm_task, settings, stats, notifications, habits, profile (own profile + friend list + activity feed + weekly winner), friend_invite_screen (deep-link target), friend_profile_page (read-only view of another user), find_friends_page (nickname search)
- `lib/models/` — Data classes (`Task`, `Habit`, `UserData`, `Achievement`+`EvalContext`, `FriendProfile`, `FriendRank`, `ActivityFeedItem`, `WeeklyWinner`, `NicknameSearchResult`) with `fromMap`/`toMap`
- `lib/services/` — Firestore + Auth wrappers (`auth_service`, `task_service`, `habit_service`, `user_service`, `image_service`, `achievement_service`, `friend_service`). `web_notification_service` is split for conditional import: `web_notification_service.dart` (facade) re-exports `_stub.dart` (non-web no-op) or `_web.dart` (browser Notifications API) — never call the platform files directly.
- `lib/widgets/` — Reusable components (`task_card`, `xp_bar`, `stats_sidebar`, `empty_state`, `neo_bottom_sheet`, `achievement_card`, `achievement_grid`, `friend_badges` = level badge + animated streak flame, `year_heatmap`, `title_chip`, etc.)
- `lib/widgets/dialogs/` — `task_form_dialog` (shared by task + habit create/edit), `achievement_detail_sheet`, `day_detail_sheet`
- `lib/constants/` — `app_colors` (neon palette), `neo_theme` (borders/shadows/radii), `game_config` (XP/coin tiers), `strings` (Czech UI strings), `layout`, `task_categories` (Práce/Osobní/Sport/Studium/Domácnost/Zdraví/Kreativita/Jiné), `achievements` (static registry of 15 achievements + predicates)
- `lib/utils/` — `date_helpers` (yyyy-MM-dd formatting + `relativeTimeCs` for activity feed), `context_extensions` (`isDark`, `primaryColor`), `ui_helpers` (snackbars), `week_helpers` (`mondayOf`, `mondayStringOf` for weekly XP reset), `invite_code` (8-char generator, no ambiguous chars), `stats_helpers`
- `lib/firebase_options.dart` — Generated Firebase config (do not edit manually)
- `test/` — Mirrors `lib/` layout for unit tests (pure logic only — Firestore I/O is not mocked)
- `docs/plans/` — Dated multi-step design + implementation plans; drop new feature plans here

### Data Model (Firestore)
```
users/{uid}/
  ├── nickname, xp, coins, level, photoUrl
  ├── streak, lastActiveDate, notificationsEnabled
  ├── activeTitle (achievement id worn as title chip)
  ├── inviteCode (8-char persistent friend invite code)
  ├── discoverable (bool, opt-in for nickname search + global leaderboard), nicknameLower (lowercased for prefix query)
  ├── weeklyXp, weeklyXpWeekStart (yyyy-MM-dd of Monday, lazy reset in confirmTask)
  ├── tasks/{taskId}/
  │   ├── title, type (daily|weekly|monthly), date (yyyy-MM-dd)
  │   ├── xp, coins, code (6-digit), completed, completedAt
  │   ├── rejected (transient), wasRejected (persistent, fuels comeback_kid)
  │   ├── rejectionReason, categories [string keys]
  │   ├── habitId (set if generated from a habit)
  │   └── imageBase64 (compressed photo proof)
  ├── habits/{habitId}/
  │   ├── title, type, recurrence (everyday|weekdays|custom), customDays [1..7]
  │   ├── startDate, active, createdAt, categories [string keys]
  │   └── streak, longestStreak, lastCompletedDate
  ├── achievements/{achId}/ → unlockedAt
  ├── weeklyWinners/{weekStart}/ → snapshot of prior-week leaderboard winner (lazy client-side, owner-only)
  ├── friends/{friendUid}/ → nickname (denormalized snapshot), addedAt
  └── notifications/{notifId}/
      └── type (confirmed|rejected|expiring|achievement|friend_pending|friend_added),
          fromUid, fromNickname, taskId, taskTitle, code, message, createdAt, read

taskCodes/{code}/ → userId, taskId           # Global confirm-flow index
userInvites/{code}/ → userId                  # Global friend-invite-link index
```

### Key Patterns
- **Service layer**: Pages call services in `lib/services/`. Services own Firestore reads/writes; pages own UI + StreamBuilder. Don't call Firestore directly from pages for new code.
- **Task rewards** are type-based via `GameConfig.rewardsFor`: daily 10xp/5coins, weekly 50xp/20coins, monthly 200xp/100coins.
- **Level**: `level = (totalXp ~/ 100) + 1`; XP bar shows `xp % 100`.
- **User streak**: tracked on user doc via `lastActiveDate`. Bonus XP awarded at exactly 7/30/100 days (`GameConfig.streakBonus`). Reset on calendar load if last active is not today/yesterday (`checkAndResetStreak`).
- **Habit streak**: separate per-habit streak. Increments only when previous expected day (`Habit.previousExpectedDay`, 14-day lookback) was completed. Updated atomically inside `confirmTask` transaction.
- **Habit instances**: created on habit creation (30 days ahead) and extended on every `CalendarPage` load via `HabitService.extendWindows()` whenever the latest instance is <14 days out. Pause/edit/delete prunes future uncompleted instances but preserves past + photo-pending ones.
- **Habit type × recurrence coupling** (`task_form_dialog`, habit mode): a Weekly habit must have exactly 1 recurrence day; Monthly is disabled for habits. `HabitService` silently migrates legacy Weekly+everyday habits to Daily in place (old data minted 250 XP/week; Daily is 50 XP/week — the migration corrects this).
- **Task code lookup**: `taskCodes/{code}` global index maps to `{userId, taskId}` for the friend-confirm flow (avoids cross-user collection scans).
- **Confirm transaction** (`TaskService.confirmTask`): all Firestore reads (user, task, habit if any) MUST happen before any writes — Firestore transactions require this ordering. Updates user XP/coins/level/streak + `weeklyXp` (lazy reset if `weeklyXpWeekStart != currentMonday`), marks task completed, updates habit streak, and creates a notification.
- **Photos**: compressed at capture (500px width, 40% quality, 750KB cap via `GameConfig`) and stored as base64 in Firestore directly.
- **Notifications**: written by `_createNotification` only if owner has `notificationsEnabled != false`. `checkExpiringTasks` runs on calendar load and dedupes by `(type, taskId)`.

### Achievements
- **Static registry** in `lib/constants/achievements.dart` — 15 achievements with pure-function predicates over an `EvalContext` snapshot. Types: situational / loreTitle / antiAchievement / milestone.
- **Eval triggers** in `AchievementService.evaluate()`:
  - `main.dart` notif-stream listener — fires on every new notif (e.g. friend confirmed your task)
  - `main.dart` auth-state restore — fires once on auto-login from cached creds
  - `login.dart` — fires on explicit sign-in
  - `task_service.createTask` + `habit_service.createHabit` — local triggers
  - `stats_page.initState` — lazy catch-up on view
- **`_running` guard** drops concurrent calls. Idempotent doc IDs (`achievement_{id}`) prevent double-unlock notifs.
- **Required Firestore index** (`firestore.indexes.json`): `tasks` collection on `(completed ASC, completedAt DESC)` for the eval's recent-tasks query. **Missing this index makes ALL achievements silently fail to unlock** — eval throws and `.catchError` swallows it. Always re-deploy indexes when touching achievement queries.

### Friends + Leaderboard
- **Invite link flow**: `/profile` → "Sdílet pozvánku" generates persistent `inviteCode` and `userInvites/{code}` index. Recipient opens `/friend?code=X` → mutual handshake confirms → both edges written under `users/{uid}/friends/{friendUid}` + `friend_added` notif.
- **Leaderboard metric**: weekly XP (Mon-Sun, lazy reset on `confirmTask`). `FriendService.leaderboardStream()` fan-ins self + each friend's user doc snapshots.
- **Compact widget** in `/stats` (hidden if 0 friends). Full leaderboard in `/profile` friend list. Rank-1 row gets neon-yellow trophy icon; nickname highlighted in primary color. Streak flame animates for streak ≥ 7.
- **Friend feed (`friend_pending` notif)**: when owner uploads photo (`task_card._savePhoto`), `FriendService.notifyFriendsOfPendingTask` fires fire-and-forget — every friend gets a deterministic `friend_pending_{taskId}` notif with the share code. Tap → `/confirm` with code pre-filled.
- **Cleanup** of `friend_pending` notifs is **owner-side** (the confirmer doesn't have read access to the owner's friends list). Hooks in `task_card.didUpdateWidget` (transition resolve) and `task_card.initState` (catch-up if user wasn't online when state changed). Idempotent batched deletes.
- **Friend profile page** (`/friend-profile?uid=X`) is read-only: avatar + nickname + level + streak + stats card (Splněno úkolů / Tento týden / Mince / Úspěchy N/15). Requires `achievements` read permission for any auth user (see rules).

### Friends v3 (2026-05-27 — "AKTIVITA KAMARÁDŮ" / discovery / web push)
- **Activity feed** (`FriendService.activityFeedStream`): per-friend `achievements` subcollection snapshots merged + sorted DESC, rendered as "AKTIVITA KAMARÁDŮ" section on `/profile`. Relative timestamps via `date_helpers.relativeTimeCs`.
- **Weekly winner snapshot** (`FriendService.fetchOrCreateLastWeekSnapshot`): lazy client-side computation of last week's leaderboard winner, persisted to `users/{uid}/weeklyWinners/{weekStart}` (owner-only — each user computes their own perspective). Shown as "PŘEDCHOZÍ TÝDEN" on `/profile`. Pure pick logic is `WeeklyWinner.pickWeeklyWinner` (unit-tested).
- **Nickname search** (`FriendService.searchByNickname`): opt-in via `discoverable` flag toggled in `/settings`; `/find-friends` page does a case-insensitive prefix query on `nicknameLower`. Needs index `users (discoverable ASC, nicknameLower ASC)`.
- **Global leaderboard** (`FriendService.globalLeaderboardStream`, top-20): only `discoverable` users, shown on `/stats` above the friends leaderboard. Needs index `users (discoverable ASC, weeklyXp DESC)`.
- **QR invite**: `qr_flutter` dialog on `/profile`, scannable from another phone (encodes the same `/friend?code=X` URL as the share link).
- **Web push notifications**: foreground-only via the browser Notifications API, permission UX in `/settings`, fires on each new in-app notif. Uses conditional import (`web_notification_service.dart` → stub on non-web, `_web.dart` via `dart:js_interop` on web).

### Design system (neobrutalism)
- `NeoTheme`: 2px borders, hard offset shadows (no blur), small radii (cards 8, buttons 6).
- `AppColors`: dark scaffold + neon accents (green/pink/yellow/cyan/orange). Theme color is user-selectable from `AppColors.themeOptions`, persisted to SharedPreferences.
- `showNeoBottomSheet` is the canonical helper for bottom sheets (consistent border + drag handle).
- Tasks color-coded by type: daily=blue, weekly=orange, monthly=purple.

### Language
All UI strings live in `lib/constants/strings.dart` in **proper Czech with diacritics** (e.g. `Uživatel není přihlášen`, `Splněno`, `Návyky`). Earlier code may still use diacritic-less forms — fix on touch. No i18n framework. When adding strings, add a constant to `Strings` rather than inlining. The brand name `MOTIVATOR` (constant `Strings.appName`) stays uppercase Latin without diacritics. Invite codes (charset in `lib/utils/invite_code.dart`) are alphanumeric-only by design.

### Firebase Project
- Project ID: `calendar-mot`
- Hosting URL: `https://calendar-mot.web.app`
- Firestore rules (`firestore.rules`):
  - `users/{uid}` — read any auth (needed for leaderboard + friend profile); write owner-only except `update` which any auth user can do (needed for confirm-flow XP additions)
  - `tasks` subcollection — read any auth (needed for confirm-flow + cross-user reads); create/delete owner-only; update any auth (confirm-flow)
  - `habits` subcollection — same pattern as tasks (habit-streak update during confirm-flow needs cross-user update)
  - `notifications` — read/update/delete owner-only by default; `delete` also allowed for original sender (`fromUid`) so friend_pending cleanup works; `create` allowed for any auth (covers cross-user confirm + reject + friend_pending writes)
  - `achievements` — read any auth (friend profile aggregation + activity feed); write owner-only
  - `weeklyWinners/{weekStart}` subcollection — read/write owner-only (derived per-user view)
  - `friends/{friendId}` subcollection — read by owner only; create/update/delete by either party (mutual transactions)
  - `taskCodes/{code}` global — read any auth; create/delete by code owner only
  - `userInvites/{code}` global — read any auth (resolve invite); create/delete by code owner only
- Indexes (`firestore.indexes.json`):
  - `tasks (completed ASC, date ASC)` — for `checkExpiringTasks` aggregate
  - `tasks (completed ASC, completedAt DESC)` — for `AchievementService._buildContext`
  - `users (discoverable ASC, nicknameLower ASC)` — for nickname search (`/find-friends`)
  - `users (discoverable ASC, weeklyXp DESC)` — for global leaderboard (`/stats`)
- Config: `.firebaserc`, `firebase.json`

### Known quirks
- **Service worker caching**: after each `firebase deploy --only hosting`, the browser must drop SW caches before the new JS bundle activates. In Playwright/manual QA: `await Promise.all([(await caches.keys()).map(k => caches.delete(k)), (await navigator.serviceWorker.getRegistrations()).map(r => r.unregister())])` + reload.
- **Firestore transactions** require all reads before writes — see `TaskService.confirmTask`.
- **Web Share API** on desktop browsers falls back to clipboard with toast — test on Chrome before assuming the share sheet opens.
- **Auto-mode evaluation flow**: when a friend confirms your rejected→resubmitted task, the unlock fires via the notif-stream listener in `main.dart`. If the user was offline at the moment, the auth-state-restore eval catches up on next login.
