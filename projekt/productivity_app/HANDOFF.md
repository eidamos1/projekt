# HANDOFF — Motivator

**Stav k:** 2026-05-30
**Branch:** `main` (vše pushnuto + nasazeno na https://calendar-mot.web.app)
**Tests:** 143/143 zelené
**Analyze:** čistý

> **v3 push DONE** (commity `f2e656f` + QA fix `09ea551`): activity feed „AKTIVITA KAMARÁDŮ", QR pozvánka, snapshot vítěze týdne, hledání podle přezdívky (`discoverable` + index), globální top-20 leaderboard, web push (foreground). Plus QA polish: 2řádkové wrapy karet úspěchů, plná 365denní heatmapa, light-mode AppBar, coupling typ×opakování návyku, mobilní stacking tlačítek + FAB clearance. Detaily v `CLAUDE.md` (sekce „Friends v3").

---

## Co je hotovo (v2 push — všechny 4 fáze)

- [x] **Fáze 1 — Návyky** (`feat/habits` → main)
  - Recurring task instances, 30-day rolling window
  - Per-habit streak (separate from user streak), pause/resume/delete
  - Generace úkolů při vytvoření + extend pri každém otevření kalendáře
- [x] **Fáze 2 — Úspěchy** (15 ks, deployed)
  - 4 typy: situational / loreTitle / antiAchievement / milestone
  - Predikátová evaluace v `lib/services/achievement_service.dart`
  - Re-entry guard, deterministické notif doc IDs
  - Title chip vedle nicku, in-app unlock toast
  - Achievement grid v /stats s filtry (vše/situační/tituly/anti/mety)
- [x] **Fáze 3 — Stats refactor + heatmapa** (deployed)
  - YearHeatmap (53×7) jako hero, right-aligned grid pro nové uživatele, "méně → více" legenda
  - Metric karty (Série / Splněno / Nejlepší den) místo původní inline summary
  - Donut chart Poměr kategorií s legendou, "Bez kategorie" jako tichý footer chip
  - Achievement grid: filtr "vše" zobrazí všech 15 karet (ne 4 sample)
- [x] **Fáze 4 — Kamarádi + žebříček** (deployed 2026-05-13)
  - Mutual-handshake invite link (`/friend?code=X` deep link)
  - Týdenní XP leaderboard, lazy reset v Mon `confirmTask` transakci
  - Hybrid UI: `/profile` (full friend list) + kompaktní widget v `/stats`
  - Passive friend-feed: foto upload → `friend_pending` notifs do friend inboxů
  - Read-only `/friend-profile?uid=X` page (level + streak + statistiky)
  - Visual polish: level badge, animovaný streak flame (≥7 dní), rank-1 trophy

## Poslední session (2026-05-14 → 15)

- **Comeback bug deep-dive**: hlavní příčina = chyběl Firestore composite index `(completed, completedAt DESC)`. Eval throw → silent `.catchError` → ŽÁDNÝ achievement nikdy neunlocknul. Fix: index přidán + `evaluate()` se spustí i na auth-state restore.
- **Friends + leaderboard polish (větev `feat/diacritics-and-friends-polish`, merged 2026-05-15)**:
  - Tap na friend řádek → `/friend-profile?uid=X` (read-only stats)
  - Level badge u nicku, streak flame animation pulse pro streak ≥ 7, trophy ikona u rank 1
  - Pravidlo: `achievements` collection read otevřen pro všechny auth (count aggregace)
- **Czech diakritika pass**: všechny user-facing stringy v `lib/constants/strings.dart` + `achievements.dart` + inline literály v pages/widgets dostaly proper diakritiku (Splněno, Návyky, Úspěchy, Pátečnízí hrdina, Půlnoční záchrana atd.). `*Accented` duplicitní konstanty smazány. Konvence v `CLAUDE.md` aktualizována. Výjimky: brand `MOTIVATOR` + invite kódy (alphanumeric only).
- **Stats empty-state polish**: friends-only uživatelé (žádné vlastní úkoly, 1+ kamarád) teď vidí leaderboard widget i v empty state na /stats.

## Posledních pár commitů

```
673d0dc Merge feat/diacritics-and-friends-polish — full Czech diacritics + friend profile + leaderboard polish
3bd6d2f fix(friends): allow auth users to read others' achievements (friend profile aggregation)
94b4372 feat(friends): level badge + streak flame animation + rank-1 trophy
87240f5 feat(friends): tap friend row → friend profile
0cea2f2 feat(friends): /friend-profile page (read-only)
14622fa feat(friends): FriendProfile model + service method
a3f5013 docs: update CLAUDE.md to reflect diacritics convention
2b560e7 chore(i18n): diacritics in inline UI strings
af97a5b chore(i18n): diacritics in achievements
a993936 chore(i18n): diacritics in strings.dart and drop *Accented duplicates
2fbe96c fix(achievements): add missing composite index (completed, completedAt DESC)
0c57f10 fix(achievements): fire evaluate on auth state restore
e697634 fix(friends): render leaderboard on /stats empty-tasks state
c05c1d7 fix(friends): allow notif sender to delete (cleanup friend_pending across friend inboxes)
415dc1f fix(friends): cleanup friend_pending notifs on TaskCard initState for already-resolved tasks
```

## Co při startu zkontrolovat

1. `git pull origin main` — sync s remote
2. `flutter pub get` + `flutter test` + `flutter analyze` (126 testů zelených)
3. `git status` — případné rozpracované změny
4. Memory v `~/.claude/projects/.../memory/` — projít user/feedback/project záznamy
5. Stav Firebase: `firebase deploy --only hosting:channel:list` (volitelně)

## Architektura (rychlý recap)

- **Service layer** v `lib/services/` — všechny Firestore IO. Pages → service → Firestore. Žádné přímé volání Firestore z pages pro nový kód.
- **Provider** `ThemeProvider` v `main.dart` — darkMode, primaryColor (z `AppColors.themeOptions`), layoutMode (kompaktní vs rozložený).
- **Routes**: `/`, `/calendar`, `/confirm`, `/settings`, `/stats`, `/notifications`, `/habits`, `/profile` (statické). `/friend?code=X` a `/friend-profile?uid=X` přes `onGenerateRoute` (query params).
- **Lokalizace**: `cs` přes `flutter_localizations`, datumy `initializeDateFormatting('cs')` PŘED `runApp`.
- **Czech UI strings**: v `lib/constants/strings.dart`, **proper Czech s diakritikou** (od 2026-05-15). Žádné inline stringy v widget vrstvě pro nový kód.
- **Neobrutalism**: `NeoTheme` (border 2px, hard shadows, radii 6–8), `AppColors` neon paleta, `showNeoBottomSheet` helper.
- **Achievements predikátové**: `lib/constants/achievements.dart` (registr 15 kusů), `models/achievement.dart` (typ + evaluate), `models/eval_context.dart`. Pure funkce nad snapshotem dat — testovatelné bez Firestore.

## Data model

```
users/{uid}/
  ├── nickname, xp, coins, level, photoUrl, activeTitle
  ├── streak, lastActiveDate, notificationsEnabled
  ├── inviteCode, weeklyXp, weeklyXpWeekStart
  ├── tasks/{taskId}/    … habitId? imageBase64, wasRejected (persistent), categories[]
  ├── habits/{habitId}/  … streak, longestStreak, lastCompletedDate, categories[]
  ├── achievements/{id}/ … unlockedAt
  ├── friends/{uid}/     … nickname snapshot, addedAt (mutual edges)
  └── notifications/{id}/… type ∈ {confirmed, rejected, expiring, achievement, friend_pending, friend_added}

taskCodes/{code}/   → userId, taskId    (global confirm-flow index)
userInvites/{code}/ → userId            (global friend-invite index)
```

## Známé pasti (quirks)

- **Service worker caching**: po každém `firebase deploy --only hosting` musí browser dropnout SW caches, jinak vidí starý JS bundle. V Playwright/manuálním QA: `await Promise.all([(await caches.keys()).map(k => caches.delete(k)), (await navigator.serviceWorker.getRegistrations()).map(r => r.unregister())])` + reload.
- **TableCalendar locale**: vyžaduje `initializeDateFormatting('cs')` v `main.dart` PŘED `runApp`.
- **Firestore transakce**: všechny `get()` před jakýmkoliv `update()`. Hlavně `TaskService.confirmTask`.
- **Achievement evaluate fan-out**: 5 trigger sites — login.dart, task_service.createTask, habit_service.createHabit, stats_page.initState, main.dart notif-stream + auth-state listener. `_running` guard drop concurrent calls. Při změně eval query VŽDY ověř že index v `firestore.indexes.json` pokrývá nové fieldy.
- **Friend_pending cleanup je owner-side**: confirmer nemůže iterovat owner's friends list. TaskCard `didUpdateWidget` + `initState` defensivně mažou. Rule povoluje delete sender ID + owner ID.
- **Web Share API** na desktopu padá do clipboardu — test na Chrome pomocí Web Share + fallback.

## Dev login (per memory)

- Hlavní: `sm@example.cz` / `dev12345` — uživatel "tralala"
- Testovací: `kamarad+test@example.cz` / `dev12345` — uživatel "kamarad" (přátelský link s tralala)
- Pokud nefunguje, registrace fresh účtu

## Co dál — open tracks

V2 i v3 push uzavřen + nasazen. Repo vyčištěno do prezentovatelného stavu (README, .gitignore na QA artefakty, 2026-05-30). Žádný track není rozpracovaný. Možné další směry:
- Expirovaný úkol → cleanup `friend_pending` notifs (drobnost; aktuálně friend tap → „task not found" graceful)
- Background push (aktuálně foreground-only web push)
- Block / report kamarádů
- i18n framework (nyní hardcoded čeština ve `Strings`)
