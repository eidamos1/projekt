# Achievements — Design

**Datum:** 2026-05-12
**Status:** Schvaleny k implementaci
**Autor:** brainstorming session
**Predchozi faze:** [Navyky (habits)](2026-04-16-habits-design.md)

## Cil

Druha faze "v2" pushe. Achievements konzumuji existujici habit streaky, task completiony, kategorie a rejected/expired stavy. Drzi se anti-AI design principu: konkretne situace s hlasem, ne genericke milestones; locked karty s vagnimi tease, ne checklist; **odemkleny titul vedle nicku** pripravuje pudu pro friends/leaderboard fazi.

## Designove principy (z habits design docu, plati pro cely v2 push)

1. **Drzet neobrutalism, ne ho redit.** Tluste cerne borders, offset shadows, neon paleta, Space Grotesk, CAPS akcentace.
2. **Achievements maji hlas, ne sablonu.** Konkretni situace s ceskym vtipem misto generickych milestones.
3. **Zadne konfety ani blokujici "LEVEL UP!" modaly.** Notifikace pres existujici in-app system + neutruzivni toast.
4. **Achievements maji surface s prirozenou socialnistou.** Title chip vedle nicku — automaticky se objevi v leaderboardu v faze 4.
5. **Locked karty se tease, ne instruktazne.** Anti-achievement nesmi byt cil ke grindovani.

## Klicova rozhodnuti (z brainstorming sesion)

- **Voice mix:** ~50% situacni + ~25% anti-achievement + ~15% lore tituly + ~10% velke milestones. Anti-AI volba — kvalita kazdeho copy > checkbox sablona.
- **Surface:** sekce uvnitr `/stats` + maly title chip vedle nicku. Zadna nova route, zadny novy bottom nav slot.
- **Viditelnost:** locked = vagni teaser (siluetal ikona, CAPS title nahrazena `???`). Konkretni kriterium az po odemknuti.
- **Odmena:** jen velke milestones (typ D) davaji XP+coins. Situacni/anti/lore = pouze titul + odemknuti.
- **Predikat eval:** pure Dart funkce s `EvalContext` (`bool Function(EvalContext)`) — 15 ~3radkovych funkci, zadny DSL framework.
- **Triggery:** owner-side hybrid — lazy eval na app start + `/stats` open, reaktivni eval v notif stream listeneru pri prijetí `confirmed` notifu + po lokalnich akcich (`createTask`, `createHabit`).
- **MVP size:** 15 achievementu peclive napsanych + registry pattern pro snadne pridavani v dalsich fazich.

---

## 1. Data model

### Firestore schema

```
users/{uid}/
  activeTitle: string | null               // klic odemknuteho achievementu
  achievements/{achievementId}/             // jen odemknute, locked se nikdy nezapisuji
    unlockedAt: 'yyyy-MM-dd HH:mm'
```

- **Achievement doc je minimalni** — staci `unlockedAt`. Vsechny ostatni atributy (title, popis, predikat) jsou v Dart registry.
- **Achievement zapis je idempotent** — `merge: false` `set` na neexistujici doc. Kdyby eval bezel 100x, write se neudela.
- **`activeTitle` jako pole na user docu** (ne subcollection) — friends/leaderboard query si ho pretahne bez extra joinu, az to bude potreba.

### Rozsireni `Task` modelu

```dart
class Task {
  // ...existujici pole
  final bool wasRejected;        // never cleared, even after rejection reset
  final String completedAt;      // 'yyyy-MM-dd HH:mm' (drive jen 'yyyy-MM-dd')
}
```

- **`wasRejected`:** nastavi se `true` v `rejectTask`, nikdy se nesmaze (nei v `resetRejected`). Default `false` u stareho doc.
- **`completedAt` upgrade:** stara hodnota '2026-04-12' (10 znaku) zustava platna. Predikaty co potrebuji cas detekuji format `length == 16` a stary skipnou. Backward compat ve `Task.fromMap`.

### Dart model

```dart
enum AchType { situational, antiAchievement, loreTitle, milestone }

class Achievement {
  final String id;                     // stable klic, snake_case
  final String title;                  // "Patecni hrdina"
  final String teaser;                 // hint kdyz locked
  final String description;            // popis po odemknuti
  final AchType type;
  final IconData icon;
  final Color color;                   // neon paleta z AppColors
  final bool isTitleEligible;          // muze se nasadit jako title?
  final int xpReward;                  // jen milestone > 0
  final int coinReward;
  final bool Function(EvalContext) evaluate;
}

class EvalContext {
  final UserSnapshot user;             // xp, level, streak, lastActiveDate
  final List<Task> recentTasks;        // posledni ~200 completed, desc by completedAt
  final List<Habit> habits;
  final Set<String> alreadyUnlocked;
  final int totalCompletedTasks;       // count() aggregation, pro milestones
}
```

### Registry

`lib/constants/achievements.dart`:

```dart
abstract final class Achievements {
  static const List<Achievement> all = [
    _patecniHrdina, _comebackKid, _pulnocniZachrana, _ranoJeMoudrejsi,
    _bourak, _hatTrick, _nedelniKlid, _univerzal,
    _prokrastinator, _zlomenySlib, _krasovePanstvi, _fantom,
    _nocniSova, _spartanek,
    _stovkar,
  ];

  static Achievement? byId(String id) =>
      all.firstWhereOrNull((a) => a.id == id);
}
```

---

## 2. Eval engine

### Sluzba

Nova `lib/services/achievement_service.dart`:

```dart
class AchievementService {
  Future<Set<String>> unlockedIds();
  Stream<Set<String>> unlockedIdsStream();
  Future<List<Achievement>> evaluate();      // vraci NOVE odemknute
  Future<void> setActiveTitle(String? id);
  Stream<String?> activeTitleStream();
}
```

### Eval algoritmus

1. Nacti `EvalContext`:
   - `user` z `users/{uid}` — 1 read
   - `recentTasks` = `tasks where completed == true orderBy completedAt desc limit 200` — 1 query
   - `habits` = `habits` collection — 1 query
   - `alreadyUnlocked` = `achievements` subcollection ids — 1 query (lightweight)
   - `totalCompletedTasks` = aggregation `count()` — 1 read
2. Pro kazdy `Achievement` v `Achievements.all`:
   - Pokud `id in alreadyUnlocked` → skip
   - Spust `a.evaluate(ctx)`. Pokud `true` → pridej do `newlyUnlocked`.
3. Batch write:
   - Pro kazdy newly unlocked: `set` na `achievements/{id}` s `unlockedAt: nowWithMinutes()`.
   - Pokud `xpReward + coinReward > 0`: transakce bumpne user xp/coins (s level recompute).
4. Pro kazdy newly unlocked: vytvor `notifications/{nid}` s `type: 'achievement'`, `achievementId`, `taskTitle: a.title`. Dedupe check `where type='achievement' and achievementId=X` pred `add`.
5. Return `newlyUnlocked` listu — UI ho pouzije pro toast.

**Cost per eval:** ~5 reads + N writes (typicky 0 writes). Cheap.

### Triggery

**Lazy (catch-up):**
- App start (`LoginPage` po auth → `evaluate()` background).
- `/stats` page open.

**Reaktivni:**
- Listener na `notificationsStream` v `main.dart` — pri nove `confirmed` notif zavola `evaluate()`.
- `HabitService.createHabit`, `TaskService.createTask` → eval po success.

**Debounce:** in-memory flag `_running`. Druhe volani vrati `[]` pokud eval prave bezi.

### Idempotence + edge cases

- **Offline → online sync:** lazy eval na next app start pretahne. Firestore `set` je idempotent.
- **User vymaze task po unlocku:** unlock zustava. (Achievementy se nikdy neodemikaji.)
- **Habit smazany:** dtto. Dokoncene instance v `recentTasks` zustanou.
- **Predikat zmenen v kodu:** uz odemknute zustanou (v Firestore). Predikat se evaluuje jen kdyz neni odemknuto.

---

## 3. UI

### A) Achievements sekce v `/stats`

Pas pod existujici staty / heatmapou. Layout:

```
ACHIEVEMENTY                       [7 / 15 odhaleno]
─────────────────────────────────────────────────────
[vse] [situacni] [tituly] [anti] [milestones]

[card] [card] [card] [card]
[card] [card] [card] [card]
[card] [card] [card] [card]   <-- locked teasers na konci
```

- **Karta:** `NeoTheme` 2px border + hard offset shadow, ~140×160 px.
- **Unlocked:** plne barevna ikona (`Achievement.color`), CAPS title, telo = `description`. Tap → bottom sheet.
- **Locked:** dark scaffold barva, sedy `?` placeholder ikona, CAPS title nahrazena `???`, telo = `teaser`. Bez tappable akci, ale `NeoTheme` press anim zustava.
- **Counter** `X / 15 odhaleno` v rohu sekce.
- **Filter chipy** — default `vse`. Pri `milestones` se ukaze progress bar na locked kartach (`78 / 100`).
- **Empty state** (0 unlocked): hint "Splni neco neobvykleho a uvidi se" + 4 sample locked karty.

### B) Achievement detail bottom sheet

`showNeoBottomSheet`:

```
            [ikona]
         PATECNI HRDINA
   Splnil jsi habit ctyri patky po sobe.

   Odemknuto 2026-05-08

   ┌─────────────────────────────┐
   │   NASADIT JAKO TITUL        │   <- jen kdyz isTitleEligible
   └─────────────────────────────┘
```

- Tap "NASADIT JAKO TITUL" → `setActiveTitle(id)` → button se prepise na *"AKTIVNI TITUL"* disabled.
- Pokud uz JE aktivni titul, button rika *"SUNDAT TITUL"* → `setActiveTitle(null)`.

### C) Title chip

**Zobrazeni:**

1. **`StatsSidebar`** na kalendari — pod nick + level radkem. Maly chip, `NeoTheme` styled, barva = `Achievement.color`. Tap → naviguje na `/stats` k te karte.
2. **`/settings` profile sekce** — pod editovatelnym nickem. Stejny chip. Tap → bottom sheet s linkem na stats.
3. **Pripraveno pro friends (faze 4):** `users/{uid}.activeTitle` je field, leaderboard query si pretahne automaticky.

Kdyz `activeTitle == null`: chip se nevykresluje (zadny "Zadny titul" placeholder).

### D) Unlock notifikace

Reuse existujici notif systemu. Novy `type: 'achievement'`. V `NotificationsPage` karta:

```
🏆  ODEMKL JSI ACHIEVEMENT
    Patecni hrdina
    Pred 2 minutami       [Zobrazit]
```

- Border barva = `Achievement.color`.
- "Zobrazit" → naviguje na `/stats` s scroll-to a 2s border pulse highlight.
- Zadny blokujici modal.

### E) Unlock toast (in-app)

Kdyz `evaluate()` vrati newly unlocked **a user je prave v appce**:

```
🏆 Odemknul jsi: Patecni hrdina
```

- Neo styled `SnackBar`, 3s, tap → naviguje na `/stats`.
- Pokud `evaluate` vrati vic najednou: ukaze posledni (ostatni zustanou v notif feedu).

### F) Komponenty

- `lib/widgets/achievement_card.dart` — locked/unlocked stav, progress bar pri milestone
- `lib/widgets/achievement_grid.dart` — `Wrap` + filter chipy
- `lib/widgets/title_chip.dart` — pouzity v `StatsSidebar` + settings
- `lib/widgets/achievement_unlock_toast.dart` — SnackBar wrapper
- `lib/widgets/dialogs/achievement_detail_sheet.dart` — bottom sheet

Zadna nova route. Integrace do existujicich `/stats`, `/settings`, `StatsSidebar`, `NotificationsPage`.

---

## 4. Content — 15 achievementu

### Situacni (8) — typ A

| # | id | Title | Teaser | Description | Trigger |
|---|---|---|---|---|---|
| 1 | `patecni_hrdina` | **Patecni hrdina** | Nekdo zna cenu vikendu. | Splnil jsi habit ctyri patky po sobe. | posledni 4 patky → habit task completed |
| 2 | `comeback_kid` | **Comeback** | Nevzdal jsi to po prvni rane. | Potvrdil jsi task, ktery byl drive zamitnut. | `t.completed && t.wasRejected` |
| 3 | `pulnocni_zachrana` | **Pulnocni zachrana** | Nekdo to nevzda ani v posledni minute. | Splnil jsi task po 23:00. | completedAt hour >= 23 |
| 4 | `rano_je_moudrejsi` | **Rano je moudrejsi** | Vstavas s prvnimi taxiky. | Splnil jsi task pred 7:00. | completedAt hour < 7 |
| 5 | `bourak` | **Bourak** | Manana? Tak ne dnes. | Splnil jsi 3+ tasky za jeden den. | groupBy date, max count >= 3 |
| 6 | `hat_trick` | **Hat-trick** | Trojita kombinace. | Splnil jsi daily, weekly i monthly task v jeden den. | groupBy date, 3 ruzne typy |
| 7 | `nedelni_klid` | **Nedelni klid** | Den odpocinku je taky den. | Splnil jsi habit ve 4 nedelich po sobe. | posledni 4 nedele → habit task completed |
| 8 | `univerzal` | **Univerzal** | Jeden mozek, sto sluzeb. | Splnil jsi tasky ze 3 ruznych kategorii v jeden den. | groupBy date, distinct categories >= 3 |

Vse `isTitleEligible: true`, `xp/coin = 0`.

### Anti-achievementy (4) — typ C

| # | id | Title | Teaser | Description | Trigger |
|---|---|---|---|---|---|
| 9 | `prokrastinator` | **Prokrastinator** | Cas leti nejak rychle, ze? | Splnil jsi 5 tasku v posledni hodine pred pulnoci. | count(hour == 23) >= 5 |
| 10 | `zlomeny_slib` | **Zlomeny slib** | Tak blizko. | Rozbil jsi habit streak 7+ dni. | any habit `longestStreak >= 7 && longestStreak > streak` |
| 11 | `krasove_panstvi` | **Krasove panstvi** | Vsechno chce trening. | Mas 3 zamitnuti za jeden tyden. | count(wasRejected in last 7d) >= 3 |
| 12 | `fantom` | **Fantom kalendare** | Planovat je snadnejsi nez plnit. | 5+ tvych tasku vyprshelo bez splneni. | count(date < today && !completed) >= 5 |

`isTitleEligible: true` — anti tituly maji v sobe self-aware vtip.

### Lore tituly (2) — typ B

| # | id | Title | Teaser | Description | Trigger |
|---|---|---|---|---|---|
| 13 | `nocni_sova` | **Nocni sova** | Den ma 24 hodin, pouziva se jen ta druha polovina. | Splnil jsi 10 tasku po 22:00. | count(hour >= 22) >= 10 |
| 14 | `spartanek` | **Spartanek** | Telo je chram. | 14denni streak na sport-kategorii habitu. | habits.any(`categories has 'sport' && streak >= 14`) |

### Milestone (1) — typ D

| # | id | Title | Teaser | Description | Trigger | XP | Coins |
|---|---|---|---|---|---|---|---|
| 15 | `stovkar` | **Stovkar** | Trochu klasika. | Splnil jsi 100 tasku. | `totalCompletedTasks >= 100` | 500 | 200 |

`isTitleEligible: false`, progress bar `X / 100` na locked karte.

---

## 5. Testing

### Unit testy

`test/services/achievement_service_test.dart` — pro kazdy z 15 achievementu jeden positive + jeden negative test:

```dart
test('patecni_hrdina unlocks after 4 consecutive Fridays', () {
  final ctx = EvalContext(
    user: _fixtureUser(),
    recentTasks: _buildFridayHabitChain(weeksBack: 4),
    habits: [_sampleHabit()],
    alreadyUnlocked: {},
    totalCompletedTasks: 4,
  );
  expect(Achievements.byId('patecni_hrdina')!.evaluate(ctx), isTrue);
});

test('patecni_hrdina does NOT unlock with 3 Fridays', () {
  final ctx = ...(weeksBack: 3);
  expect(Achievements.byId('patecni_hrdina')!.evaluate(ctx), isFalse);
});
```

Plus 2 integration testy:
- `evaluate()` skipne uz odemknute (idempotence).
- `setActiveTitle` prepise predchozi titul.

`test/models/task_test.dart` — pridat:
- `Task.fromMap` se starym `completedAt` (10 znaku) — neselze.
- `Task.fromMap` s novym `completedAt` (16 znaku) — parse OK.
- `wasRejected` default `false` u starych dokumentu.

### Manualni acceptance kriteria

1. Po cisty install + 1 confirm task: `prvni_krok` (pokud bude pridan jako smoke achievement v faze 1) odemknuti → toast + notif + viditelne v `/stats`.
2. Odemkni 3 achievementy ruznych typu v rade rychle akci → vsechny 3 v `/stats` jako unlocked, 3 notif v feedu, posledni v toast.
3. Tap na unlocked card → bottom sheet otevre. Tap "Nasadit jako titul" → chip se objevi v sidebaru kalendare + v settings.
4. Sundej titul → chip zmizí, ne placeholder.
5. Reinstal appky → odemknute prijdou z Firestore (lazy eval).
6. Vytvor habit → eval bezi background, nic noveho neodemkne.
7. Locked karta v `/stats` ma `???` title + teaser, ne kriterium.
8. Milestone (`stovkar`) locked karta ma progress bar (`X / 100`), ostatni locked karty NE.
9. Filter chipy: tap `tituly` → ukazou se jen lore titles (unlocked + locked). Tap `vse` → vsechny.
10. Zamitnut task pak ho potvrdit znova → `comeback_kid` odemknuti.

---

## 6. Co NENI v MVP (yagni)

- **Sdileni achievementu** (screenshot → social) — pridame v faze 4 (friends).
- **Repeatable / leveled achievementy** (Bronz/Stribro/Zlato) — kazdy ach je jednorazovy.
- **Skryte "secret" achievementy** — vse ma teaser, zadny "?? / ??" hokus pokus.
- **Notifikace pred odemknutim** ("Jeste 2 patky a..."). Teaser staci.
- **Push notifikace** — appka push nema.
- **Animace pri unlock** krome 2s border pulse v stats pri navigate-from-notif. Zadne konfety, zadny blokujici modal.
- **Achievement editor / admin panel** — vse v kodu (registry pattern).
- **Migrace existujicich tasku** — backward compat ve `Task.fromMap`.

---

## 7. Rollout poradí (input pro `writing-plans`)

Pro implementaci ve fazich, kazda samostatne testovatelna a mergeable. Phase-level review batchovani: 1-3 → review, 4 → review, 5-7 → review.

1. **Foundation:** `Achievement` model, `Achievements` registry (prazdne), `EvalContext`, prazdny `AchievementService`. Jeden trivialni achievement (`prvni_krok` — splnil prvni task) jako smoke. Unit testy.
2. **Eval engine + Firestore:** `evaluate()` impl, write/read achievementu, idempotence. Triggers: app start + notif stream listener.
3. **Task model upgrade:** `wasRejected` + full `completedAt`, backward compat. Unit testy `Task.fromMap` na oba formaty. Update `task_service.dart` (`confirmTask`, `rejectTask`).
4. **Content batch — 15 predikat:** rozsiri registry, kazdy s positive + negative testem.
5. **UI — stats sekce:** `AchievementGrid` + `AchievementCard` + filter chipy + detail bottom sheet.
6. **Title management:** `setActiveTitle`, `TitleChip`, integrace do `StatsSidebar` + `/settings`.
7. **Unlock surface:** `achievement` notif type v `NotificationsPage`, unlock toast, highlight-on-navigate.

---

## 8. Otevrene otazky / follow-upy mimo MVP

- **Sdileni achievementu** — az s friends fazi.
- **"Coming soon" achievementy** — kdyz pridame v dalsi faze, mela by byt viditelna ze "neco prijde", nebo silent release?
- **Migrate stary `completedAt`?** Zatim ne. Pokud se ukaze ze backward compat checks v predikatech jsou ošklive, jednorazova migrace pres skript.
- **Hard cap na "Prokrastinator" frekvenci?** Aktualne odemknuti `count(hour == 23) >= 5` — 5 noci, mohlo by trvat dlouho. Pokud se ukaze ze nikdo neodemyka, zmensit prah na 3.
