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
- **Navigation**: Named routes in `main.dart` — `/` (Login), `/calendar`, `/confirm`, `/settings`, `/stats`, `/notifications`, `/habits`
- **Deep linking**: `app_links` package, custom scheme `adamapp://confirm?code=<code>`, web fragment URLs
- **Charts**: `fl_chart` (stats page)

### Project Structure
- `lib/main.dart` — App entry, `ThemeProvider`, route table, deep link handling, `navigatorKey`
- `lib/pages/` — Full-screen pages (login, calendar, confirm_task, settings, stats, notifications, habits)
- `lib/models/` — Data classes (`Task`, `Habit`, `UserData`) with `fromMap`/`toMap`
- `lib/services/` — Firestore + Auth wrappers (`auth_service`, `task_service`, `habit_service`, `user_service`, `image_service`)
- `lib/widgets/` — Reusable components (`task_card`, `xp_bar`, `stats_sidebar`, `empty_state`, `neo_bottom_sheet`, etc.)
- `lib/widgets/dialogs/` — `task_form_dialog` (shared by task + habit create/edit)
- `lib/constants/` — `app_colors` (neon palette), `neo_theme` (borders/shadows/radii), `game_config` (XP/coin tiers), `strings` (Czech UI strings), `layout`
- `lib/utils/` — `date_helpers` (yyyy-MM-dd formatting), `context_extensions` (`isDark`), `ui_helpers`
- `lib/firebase_options.dart` — Generated Firebase config (do not edit manually)
- `test/models/`, `test/services/` — Unit tests for pure logic (habit recurrence, expansion, fromMap/toMap)
- `docs/plans/` — Dated multi-step implementation plans (e.g. `2026-04-16-habits-design.md`); drop new feature plans here

### Data Model (Firestore)
```
users/{uid}/
  ├── nickname, xp, coins, level, photoUrl
  ├── streak, lastActiveDate, notificationsEnabled
  ├── tasks/{taskId}/
  │   ├── title, type (daily|weekly|monthly), date (yyyy-MM-dd)
  │   ├── xp, coins, code (6-digit), completed, completedAt
  │   ├── rejected, rejectionReason
  │   ├── habitId (set if generated from a habit)
  │   └── imageBase64 (compressed photo proof)
  ├── habits/{habitId}/
  │   ├── title, type, recurrence (everyday|weekdays|custom), customDays [1..7]
  │   ├── startDate, active, createdAt
  │   └── streak, longestStreak, lastCompletedDate
  └── notifications/{notifId}/
      └── type (confirmed|rejected|expiring), taskTitle, message, fromNickname, createdAt, read

taskCodes/{code}/    # Global index for confirm-flow lookup
  └── userId, taskId
```

### Key Patterns
- **Service layer**: Pages call services in `lib/services/`. Services own Firestore reads/writes; pages own UI + StreamBuilder. Don't call Firestore directly from pages for new code.
- **Task rewards** are type-based via `GameConfig.rewardsFor`: daily 10xp/5coins, weekly 50xp/20coins, monthly 200xp/100coins.
- **Level**: `level = (totalXp ~/ 100) + 1`; XP bar shows `xp % 100`.
- **User streak**: tracked on user doc via `lastActiveDate`. Bonus XP awarded at exactly 7/30/100 days (`GameConfig.streakBonus`). Reset on calendar load if last active is not today/yesterday (`checkAndResetStreak`).
- **Habit streak**: separate per-habit streak. Increments only when previous expected day (`Habit.previousExpectedDay`, 14-day lookback) was completed. Updated atomically inside `confirmTask` transaction.
- **Habit instances**: created on habit creation (30 days ahead) and extended on every `CalendarPage` load via `HabitService.extendWindows()` whenever the latest instance is <14 days out. Pause/edit/delete prunes future uncompleted instances but preserves past + photo-pending ones.
- **Task code lookup**: `taskCodes/{code}` global index maps to `{userId, taskId}` for the friend-confirm flow (avoids cross-user collection scans).
- **Confirm transaction** (`TaskService.confirmTask`): all Firestore reads (user, task, habit if any) MUST happen before any writes — Firestore transactions require this ordering. Updates user XP/coins/level/streak, marks task completed, updates habit streak, and creates a notification.
- **Photos**: compressed at capture (500px width, 40% quality, 750KB cap via `GameConfig`) and stored as base64 in Firestore directly.
- **Notifications**: written by `_createNotification` only if owner has `notificationsEnabled != false`. `checkExpiringTasks` runs on calendar load and dedupes by `(type, taskId)`.

### Design system (neobrutalism)
- `NeoTheme`: 2px borders, hard offset shadows (no blur), small radii (cards 8, buttons 6).
- `AppColors`: dark scaffold + neon accents (green/pink/yellow/cyan/orange). Theme color is user-selectable from `AppColors.themeOptions`, persisted to SharedPreferences.
- `showNeoBottomSheet` is the canonical helper for bottom sheets (consistent border + drag handle).
- Tasks color-coded by type: daily=blue, weekly=orange, monthly=purple.

### Language
All UI strings live in `lib/constants/strings.dart` in **proper Czech with diacritics** (e.g. `Uživatel není přihlášen`). Earlier code may still use diacritic-less forms — fix on touch. No i18n framework. When adding strings, add a constant to `Strings` rather than inlining. The brand name `MOTIVATOR` (constant `Strings.appName`) stays uppercase Latin without diacritics.

### Firebase Project
- Project ID: `calendar-mot`
- Hosting URL: `https://calendar-mot.web.app`
- Firestore rules: `firestore.rules` (owner can CRUD own data; any auth'd user can update for confirm flow; `taskCodes` writable only by code owner)
- Config: `.firebaserc`, `firebase.json`
