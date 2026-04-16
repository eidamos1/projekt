# Návyky (Recurring Tasks) — Design

**Datum:** 2026-04-16
**Status:** Schválený k implementaci
**Autor:** brainstorming session

## Cíl

Přidat recurring úkoly (návyky) jako první feature "v2" pushe. Návyk = šablona, která automaticky generuje instance úkolů na konkrétní dny. Instance se chovají jako obyčejné úkoly (kód, fotka, potvrzení kamarádem). Plní fundament pro navazující features (achievements, statistiky, leaderboard) — konzistentní chování dá appce hodnotná data, která achievementy a statistiky teprve dají smysl.

## Designové principy (platí pro celý v2 push)

1. **Držet neobrutalism, ne ho ředit.** Tlusté černé borders, offset shadows, neon paleta, Space Grotesk, CAPS akcentace. Žádné gradientové kartičky, žádné kulaté progress ringy.
2. **Achievements mají hlas, ne šablonu.** Konkrétní situace s českým vtipem místo generických milestones.
3. **Žádné konfety ani blokující "LEVEL UP!" modály.** Notifikace přes existující in-app systém.
4. **Habits se neoddělí do vlastního světa.** Integrují se do kalendáře jako úkoly s malým `↻` indikátorem.
5. **Stats nejsou dashboard.** Velká roční heatmapa v neo stylu jako hrdina obrazovky.

## Pořadí celého v2 pushe

1. **D — Návyky** (tento dokument) — foundation
2. **C — Achievements** — konzumují habit streaks
3. **Stats refactor** — vizualizuje habit + task historii
4. **B — Přátelé + leaderboard** — poslední, staví na všem předchozím

---

## 1. Koncept & data model

### Co je návyk

Šablona úkolu s pravidlem opakování. Appka pro budoucí dny automaticky vytvoří `Task` dokumenty (instance) s polem `habitId`. Instance jsou vizuálně stejné jako ruční úkoly, liší se jen drobným `↻` indikátorem u type chipu. Potvrzují se kódem přesně jako jakýkoli jiný úkol.

### Firestore schema

```
users/{uid}/habits/{habitId}
  title:               string
  type:                'daily' | 'weekly' | 'monthly'   // reward tier
  recurrence:          'everyday' | 'weekdays' | 'custom'
  customDays:          int[]   (1..7, 1=Po; jen když recurrence='custom')
  startDate:           'yyyy-MM-dd'
  active:              bool
  createdAt:           timestamp
  streak:              int     // per-habit current streak
  longestStreak:       int
  lastCompletedDate:   'yyyy-MM-dd' | null
```

Rozšíření existujícího `Task` modelu:

```
users/{uid}/tasks/{taskId}
  ...existující pole
  habitId: string | null
```

### Klíčová rozhodnutí

- **Habit je samostatná kolekce.** Jedno místo pravdy pro title/type/recurrence, instance ji jen referencují přes `habitId`.
- **Reward tier se volí nezávisle na recurrence.** Smart default: `everyday→daily`, `weekdays→daily`, `custom→weekly`. Override dovolen, warning pod dropdownem pokud kombinace je neobvyklá (např. `everyday + monthly tier`).
- **Dokončené instance přežijí smazání habitu.** `habitId` u instance zůstane jako dangling reference; pro stats a historii je instance dál platná.
- **Žádný per-habit reward override.** Reward vychází z `type` instance (= `type` habitu v okamžiku generování instance).

### Co NENÍ v MVP

- "Každý N-tý den" recurrence
- Připomenutí v konkrétní čas (vyžaduje push, které app nemá)
- Per-habit reward override
- Kategorie / tagy / priority návyků
- Import / archivace

---

## 2. Generování instancí — rolling window

### Strategie

- **Při vytvoření návyku:** vygeneruj instance pro následujících 30 dní od `startDate`, jen pro dny, které odpovídají recurrence.
- **Při otevření kalendáře:** pro každý aktivní habit zkontroluj, jestli poslední instance je ≥14 dní vepředu. Pokud ne, dogeneruj do 30 dní. Rolling window.
- **Při pozastavení habitu** (`active=false`): smazat budoucí *nedokončené a nepending* instance. Dokončené a pending (s fotkou čekající na potvrzení) zůstávají.
- **Při smazání habitu:** totéž + smazat habit doc. Instance s `habitId` ukazujícím na zaniklý doc jsou valid — chovají se jako normální úkoly.
- **Při editaci habitu** (title/type/recurrence): dialog `"Upravit jen tento úkol, nebo celý návyk?"`. "Celý návyk" = update habit + regeneruj budoucí nedokončené instance. "Jen tento" = klasický task edit jako dnes.

### Proč ne jiné přístupy

- **Seed 365 dní upfront** — Firestore writes kostují, zbytečné.
- **Cloud Function denně** — projekt nemá Cloud Functions setup, overkill.
- **Lazy per-day** (generovat až při selectu dne) — rozbije kalendářové markery.

### Kód pro potvrzení

Každá instance má vlastní 6-místný `code`. Existující `TaskService.createTask` logiku zrefaktorovat na interní `_createTaskInstance(title, type, date, habitId?)`, kterou volá jak `createTask` (habitId=null), tak generátor v `HabitService`.

### Kde se extend rolling window volá

V `CalendarPage.initState()` po `checkAndResetStreak()` a `checkExpiringTasks()` přidat `habitService.extendWindows()`. Sedne do existujícího vzoru init-time startup check.

### Edge cases

- **Offline 10 dní:** rolling window se extend od dneška; staré nesplněné instance zůstanou viditelné, user je může potvrdit nebo smazat.
- **DST / TZ změna:** používáme lokální `yyyy-MM-dd`, stejně jako `todayString()`. Žádná extra logika.
- **Retroaktivní edit recurrence** (odebrání dní): smažou se budoucí nedokončené instance těchto dnů. Dokončené zůstanou; past se nerewritne.
- **Collision s ručním úkolem:** dva tasky na stejný den jsou OK, visual diff přes `↻`.

---

## 3. UI integrace

### Vytvoření návyku — rozšířený TaskFormDialog

Zachovat existující dialog, jen rozšířit:

```
[ Název úkolu                      ]
[ Typ úkolu ▾                      ]
─────────────────────────────────────
  ◯ Opakovat pravidelně              ← SwitchListTile

  (když zapnuté:)
  [Každý den][Všední dny][Vlastní]   ← SegmentedButton (neo style)

  (když "Vlastní":)
  (Po)(Út)(St)(Čt)(Pá)(So)(Ne)       ← ChoiceChips, multi-select
```

Defaulty:
- Toggle off = dnešní chování, žádný regres.
- Toggle on → "Každý den" předvybrané.
- Přepnutí na "Vlastní" → zvýrazní se aktuální weekday.
- Smart type default: `everyday/weekdays → daily`, `custom → weekly`.
- Kombinace `monthly tier + everyday` = warning pod dropdownem: *"Monthly tier při denní frekvenci = hodně XP."* — nezakázat, jen varovat.

### Instance na kalendáři

- Měsíční view: žádné nové markery, pořád jen dots podle `type`.
- Task card: u type chipu přibude malý `↻` ikon (stejná barva jako typeColor, `NeoTheme.borderWidthThin`). Visual diff minimální — instance JE task.

### Správa návyků — nová stránka `/habits`

Přístup:
- Z popup menu na calendar page ("Moje návyky").
- Ze settings page ("Moje návyky" row).

Layout (neo style, sleduje TaskCard):

```
┌──────────────────────────────────┐
│ ▌ RANNÍ BĚH              [ ↻ ]  │   ← colored top accent + ↻ chip
│ Každý den · Denní tier           │
│ 🔥 14 dní  ·  rekord: 23        │
│ ─────────────────────────        │
│ [Pozastavit]         [Upravit]   │
└──────────────────────────────────┘
```

- Dlouhý stisk → bottom sheet `Upravit / Pozastavit|Aktivovat / Smazat` (pattern z TaskCard).
- Edit → TaskFormDialog pre-filled s habitem + zapnutým toggle.
- **Žádný FAB.** Tvorba jen přes kalendář + toggle, aby existoval jeden flow.
- Empty state: *"Ještě nemáš žádné návyky. Přidej jeden při tvorbě úkolu."*

### Edit flow — "Jen tento / Celý návyk"

Otevření edit dialogu nad instancí habitu:
- Po kliku na "Uložit" confirmation sheet se dvěma tlačítky: `Jen tento úkol` / `Celý návyk`.
- **Vždy se zeptat**, žádný smart default. Matoucí default je horší než klik navíc.
- "Jen tento" = update jen tomu taskId; habit zůstává.
- "Celý návyk" = update habit doc + regen budoucích nedokončených instancí.

---

## 4. Streak logika

### Dva streaky, každý měří jinou věc

**User streak** (existuje, beze změny):
- Dny po sobě, kdy user splnil *jakýkoli* úkol.
- Reset pokud `lastActive` není dnes/včera.
- Bonus XP na 7/30/100 (`GameConfig.streakBonus`).

**Habit streak** (nový, per-habit):
- Počet po sobě jdoucích *expected* dnů daného habitu, kdy byla instance splněná.
- "Expected" = den kdy habit má běžet podle recurrence. Víkend u "weekdays" recurrence nerozbije streak.
- Uloženo na habit docu: `streak`, `longestStreak`, `lastCompletedDate`.
- Update se provádí **ve stejné transakci jako `confirmTask`**. Pokud `taskData.habitId != null`, transakce:
  1. Označí instance `completed`.
  2. Updatuje user XP/coins/level/userStreak (jako dnes).
  3. Přečte habit doc, spočte nový streak, updatne habit doc.

### Žádný extra XP za habit streak

- User streak bonus stačí jako retence loop.
- Dvojí XP by rozbilo balance.
- Místo toho: **achievements konzumují habit streaks** (feature C). Např. `Vzor pondělí` = 4 pondělí v řadě, `Železná vůle` = habit streak 30.

### Viditelnost

- `/habits` karta: `🔥 14 dní · rekord: 23`.
- TaskCard instance: **habit streak se neukazuje** (přeplácanost).
- Stats stránka (po refactoru C-Stats): roční heatmapa zvýrazní habit streaks.

### Edge cases

- **Smazaný habit v polovině streaku:** streak zanikne s habit docem. Znovu vytvořený habit začíná od 0.
- **Pozastavený habit:** streak zamrzne, nerozbije se. Po aktivaci se zase posouvá podle expected dní.

---

## 5. Nové stringy (Czech)

```dart
// Habits
habit = 'Navyk';
habitAccented = 'N\u00e1vyk';
habits = 'Navyky';
habitsAccented = 'N\u00e1vyky';
habitsMine = 'Moje navyky';
repeatTask = 'Opakovat pravidelne';
recurrenceEveryday = 'Kazdy den';
recurrenceWeekdays = 'Vsedni dny';
recurrenceCustom = 'Vlastni';
recurrenceLabel = 'Opakovani';
chooseDays = 'Vyber dny';
habitStreak = 'Serie navyku';
habitRecord = 'rekord';
editHabitOrInstance = 'Upravit jen tento ukol, nebo cely navyk?';
thisOnly = 'Jen tento';
wholeHabit = 'Cely navyk';
pauseHabit = 'Pozastavit';
resumeHabit = 'Aktivovat';
deleteHabit = 'Smazat navyk';
deleteHabitConfirm = 'Smaze vsechny budouci instance. Minule zustanou.';
noHabitsTitle = 'Jeste nemas zadne navyky';
noHabitsSubtitle = 'Pridej jeden pri tvorbe ukolu.';
rewardTierWarning = 'Monthly tier pri denni frekvenci = hodne XP.';
```

---

## 6. Rozložení souborů

**Nové:**
- `lib/models/habit.dart` — `Habit` model + `RecurrenceType` enum + `fromMap`/`toMap`
- `lib/services/habit_service.dart` — CRUD, `generateInstances`, `extendWindows`, streak update helpery
- `lib/pages/habits_page.dart` — management list

**Upravit:**
- `lib/models/task.dart` — `habitId: String?` pole + serializace
- `lib/services/task_service.dart` — rozšířit `confirmTask` transakci o habit streak update; zrefaktorovat `createTask` na interní `_createTaskInstance` použitelný i pro generátor
- `lib/widgets/dialogs/task_form_dialog.dart` — recurrence sekce, smart default type, warning
- `lib/widgets/task_card.dart` — `↻` indikátor vedle type chipu když `task.habitId != null`
- `lib/pages/calendar_page.dart` — volat `habitService.extendWindows()` v `initState`, přidat "Moje návyky" do popup menu; dialog "Jen tento / Celý návyk" při editu instance
- `lib/pages/settings.dart` — odkaz "Moje návyky" (trasa `/habits`)
- `lib/main.dart` — trasa `/habits`
- `lib/constants/strings.dart` — nové stringy (sekce 5)

---

## 7. Akceptační kritéria

- [ ] Vytvoření úkolu bez toggle funguje jako dřív (žádný regres).
- [ ] Toggle "Opakovat pravidelně" → volba recurrence → vytvoření 30 instancí v příštích 30 dnech.
- [ ] Vsedni dny recurrence negeneruje instance na sobotu/neděli.
- [ ] Custom recurrence generuje jen na vybrané dny.
- [ ] `↻` indikátor se zobrazí na task card pokud `task.habitId != null`.
- [ ] Potvrzení instance kódem updatne habit streak ve stejné transakci jako user XP.
- [ ] Editace instance → dialog "Jen tento / Celý návyk" → "Celý návyk" regeneruje budoucí instance.
- [ ] Pozastavení habitu → budoucí nedokončené instance zmizí z kalendáře.
- [ ] Smazání habitu → habit zmizí + budoucí nedokončené instance zmizí; historie zůstává.
- [ ] Stránka `/habits` dostupná ze settings i popup menu; zobrazí seznam habitů se streakem.
- [ ] Varování při `monthly tier + everyday recurrence`.
- [ ] Při otevření kalendáře se rolling window extenduje, pokud poslední instance < 14 dní vepředu.
