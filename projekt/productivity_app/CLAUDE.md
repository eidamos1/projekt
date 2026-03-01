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

# Run tests (none exist yet)
flutter test
```

## Architecture Overview

**Motivator** — a gamified productivity app where users create tasks, attach photo proof, and share them with friends for confirmation. Friends verify tasks via deep links, triggering XP/coin rewards and level-ups. Built with Flutter + Firebase.

### Tech Stack
- **Flutter 3.9+** with Material 3, targeting Web, Android, iOS, Windows, macOS
- **Firebase**: Auth (email/password + Google Sign-In), Cloud Firestore, Hosting
- **State**: Provider (`ThemeProvider` in main.dart) + StreamBuilder for Firestore real-time data
- **Navigation**: Named routes defined in `main.dart` (`/` → Login, `/calendar` → CalendarPage, `/confirm` → ConfirmTaskPage, `/settings` → SettingsPage)
- **Deep linking**: `app_links` package, custom scheme `adamapp://confirm?code=<code>`, web fragment URLs

### Project Structure
- `lib/main.dart` — App entry, ThemeProvider, route table, deep link handling
- `lib/pages/` — Full-screen pages (login, calendar_page, confirm_task, settings, add_task)
- `lib/models/` — Data classes (`Task` with `TaskType` enum, `UserData`)
- `lib/widgets/` — Reusable components (`TaskCard`, `XPBar`)
- `lib/firebase_options.dart` — Generated Firebase config (do not edit manually)

### Data Model (Firestore)
```
users/{uid}/
  ├── nickname, xp, coins, level, photoUrl
  └── tasks/{taskId}/
      ├── title, type (daily|weekly|monthly), date (yyyy-MM-dd)
      ├── xp, coins, code (6-digit), completed (bool)
      └── imageBase64 (base64-encoded photo proof)
```

### Key Patterns
- **Task rewards** are type-based: daily (10xp/5coins), weekly (50xp/20coins), monthly (200xp/100coins)
- **Level formula**: `level = (totalXp ~/ 100) + 1`, XP bar shows `xp % 100`
- **Task confirmation** uses Firestore transactions for atomic XP/coin/level updates
- **Task code lookup** scans all users' task subcollections (no global index)
- **Images** are compressed at capture (500px width, 40% quality) and stored as base64 in Firestore
- **No service/repository layer** — pages interact with Firestore directly via StreamBuilder and inline queries

### Language
All UI strings are hardcoded in **Czech**. No i18n framework is set up.

### Firebase Project
- Project ID: `calendar-mot`
- Hosting URL: `https://calendar-mot.web.app`
- Config file: `.firebaserc`
