# Stats refactor — Design

**Datum:** 2026-05-13
**Status:** Schvaleny k implementaci
**Predchozi faze:** [Achievements](2026-05-12-achievements-design.md)

## Cil

Treti faze "v2" pushe. Promenit `/stats` z dashboard-page (4 stat cards + 2 pies + bar chart) na **heatmap-hero** stranku. Vrchol = 365-bunkova rocni heatmapa, pod ni achievementy + pomer kategorii. Drzi se v2 design principu z habits docu: *"Stats nejsou dashboard. Velka rocni heatmapa v neo stylu jako hrdina obrazovky."*

## Klicova rozhodnuti (z brainstorming sesion)

- **Bunka heatmapy = pocet splnenych ukolu** (5 buckety: 0/1/2/3/4+). Anti-AI: prosty signal, GitHub-contributions vzor. Habity nemaji vlastni radky — vidi se v hlavnim gridu.
- **Casovy rozsah:** rolling last 365 days (heatmapa konci dneskem, sahaje rok zpet). Vyhne se "prazdny rok ceka" pri novem uctu. Aktualni rok fixed prijde az s vetsim datasetom.
- **Habit streaks vizualizace:** pouze global user streak counter (`🔥 14 / rekord 23`) nahore. Per-habit detail patri na `/habits`. Stats = rocni obraz, ne habit dashboard.
- **Interakce:** tap na bunku → neo bottom sheet s detailem dne (datum + total XP + list splnenych ukolu).
- **Co zustava na strance:** stat header strip (Splneno · Celkem · Nejlepsi den) + heatmapa + achievement grid + pomer kategorii pie.
- **Co se odstrani:** 4 stat cards, "Nejproduktivnejsi den" list tile (presunut do header strip), XP bar chart 7 dni, pomer typu ukolu pie.
- **Barva:** intensity scale pres `context.primaryColor` (theme-aware). 0=bgSubtle, 1-4=primary @ 25/50/75/100% opacity.
- **Orientace:** horizontalni grid 53 sloupcu × 7 radek. Compact mobile = horizontal scroll.

---

## 1. Data model + agregace

Zadna Firestore zmena. Vsechno na klientu z `_allTasks: List<Task>` (uz existuje).

```dart
/// Vrati Map<yyyy-MM-dd → pocet splnenych ukolu> za posledni 365 dni.
Map<String, int> tasksPerDay(List<Task> tasks) {
  final counts = <String, int>{};
  for (final t in tasks) {
    if (!t.completed) continue;
    counts.update(t.date, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}
```

Typicky <1000 tasku → O(n) iterace, neproblem.

`bestDay` (Nejlepsi den) — uz se pocita ve `stats_page.dart`, reuse.

---

## 2. `YearHeatmap` widget

### Soubor

`lib/widgets/year_heatmap.dart`.

### API

```dart
class YearHeatmap extends StatelessWidget {
  final Map<String, int> tasksPerDay;
  final String? firstTaskDate;  // yyyy-MM-dd; bunky pred tim transparentni
  final void Function(DateTime date) onCellTap;

  const YearHeatmap({...});

  static int intensityBucket(int count) {
    if (count <= 0) return 0;
    if (count >= 4) return 4;
    return count;
  }

  static List<DateTime> cellsFor(DateTime today, Map<String, int> _) {
    // 53 sloupcu × 7 radek, posledni napravo = aktualni tyden.
    // ...
  }
}
```

### Layout

- **Grid:** 53 sloupcu × 7 radek. Posledni sloupec napravo = aktualni tyden, nejlevejsi = pred ~52 tydny.
- **Mezery:** 2px mezi bunkami.
- **Bunka:**
  - Widescreen (`isWide`): `18×18 px`
  - Compact: `12×12 px` + horizontal scroll wrap
- **Ramecek celeho gridu:** 2px cerny, 8px padding.
- **Hard offset shadow** kolem gridu (`NeoTheme.shadowOffset`).

### Intenzita = barva

| Count | Pozadi |
|---|---|
| 0 | `bgSubtle` — dark: `#1A1A24` / light: `#E8E8E8` |
| 1 | `primary @ 25% alpha` |
| 2 | `primary @ 50% alpha` |
| 3 | `primary @ 75% alpha` |
| 4+ | `primary @ 100% alpha` |

`primary` je `context.primaryColor` (theme-switcher respected).

### Pre-signup bunky

Datum pred `firstTaskDate` (nebo `firstTaskDate == null` u uplne fresh uctu): `Color(0x0AFFFFFF)` transparent-ish. Vizualne "tady jsme jeste neexistovali."

### Labely

- **Mesicni labely nad gridem:** male texty `led`, `uno`, `bre`, ..., `pro` — nad sloupcem kde dany mesic ZACINA.
- **Tyzdennie labely vlevo:** `Po`, `St`, `Pa` (kazdy 2. den) — sedy maly text.

### Tap

`GestureDetector` per bunka. Tap s `count > 0` → `onCellTap(date)`. Tap s `count == 0`: nedela nic.

### Performance

Pristup: `Column(List<Row(List<Container>)>)` — `7 × 53 = 371` widgetu. Pod 16ms i pri rebuild.

Fallback (kdyby pomale): `CustomPaint`. Posledni reseni.

---

## 3. `DayDetailSheet`

### Soubor

`lib/widgets/dialogs/day_detail_sheet.dart`.

### Helper

```dart
void showDayDetailSheet(BuildContext context, DateTime date, List<Task> dayTasks) {
  showNeoBottomSheet<void>(context: context, children: [
    DayDetailSheet(date: date, tasks: dayTasks),
  ]);
}
```

### Obsah

- **Header:** `DateFormat('EEEE, d. MMMM yyyy', 'cs').format(date)` — napr. `pondeli, 23. brezna 2026`.
- **Sub-header:** `{count} ukolu · {totalXp} XP`.
- **List splnenych tasku** ten den. Kazdy radek:
  - `↻` icon vlevo (jen kdyz `t.habitId != null`).
  - Title.
  - Reward XP napravo.
  - Pod tim category chip(y).
- **Tap na radek:** zatim nic, YAGNI.

### Volajici

`StatsPage` filtruje:

```dart
final dayTasks = _allTasks
    .where((t) => t.completed && t.date == formatDate(date))
    .toList();
showDayDetailSheet(context, date, dayTasks);
```

---

## 4. `stats_page.dart` final layout

```
┌─────────────────────────────────────────────┐
│  Statistiky                                 │
└─────────────────────────────────────────────┘

🔥 14 dni / rekord 23                          ← kdyz user.streak > 0

POSLEDNICH 365 DNI
[heatmap 53×7, mesicni label nad, tydenni vlevo]

Splneno 31 · Celkem 42 · Nejlepsi den: stredy   ← summary strip pod heatmapou

──────────────────────────────────────────────

USPECHY                            3 / 15 odhaleno
[filter chips]
[achievement grid]

──────────────────────────────────────────────

POMER KATEGORII
[pie chart]

[bottom nav]
```

### Pridane strings (`lib/constants/strings.dart`)

```dart
static const lastYear = 'POSLEDNICH 365 DNI';
static const categoryRatio = 'POMER KATEGORII';
static String streakLine(int current, int record) =>
    '🔥 $current dni / rekord $record';
static String summaryLine(int splneno, int celkem, String? bestDay) =>
    bestDay == null
        ? 'Splneno $splneno · Celkem $celkem'
        : 'Splneno $splneno · Celkem $celkem · Nejlepsi den: $bestDay';
```

Vse czech-no-diacritics.

### Cleanup ze stareho `stats_page.dart`

Odstranit:
- `_StatCard` 4 widgety (Celkem, Splneno, Tento tyden, Tento mesic).
- `Container` s `Nejproduktivnejsi den` list tile.
- `BarChart` "XP za poslednich 7 dni" celá sekce.
- `PieChart` `Pomer typu ukolu` celá sekce.

Zustava:
- `_allTasks` loading.
- `_unlockedAtMap` loading (achievements).
- `_loadStats` plus achievement eval trigger.
- `AchievementGrid` widget + `showAchievementDetailSheet`.
- `Pomer kategorii` pie.
- `bestDay` computation (reuse v summary strip).

---

## 5. Testing

### Unit testy

`test/widgets/year_heatmap_test.dart`:

```dart
test('cellsFor returns 53 weeks × 7 days', () {
  final cells = YearHeatmap.cellsFor(DateTime(2026, 5, 13), {});
  expect(cells.length, 53 * 7);
});

test('intensity bucket 0 for empty day', () {
  expect(YearHeatmap.intensityBucket(0), 0);
});

test('intensity bucket 4 for 4+ tasks', () {
  expect(YearHeatmap.intensityBucket(4), 4);
  expect(YearHeatmap.intensityBucket(10), 4);
});

test('intensity bucket distribution 1..3', () {
  expect(YearHeatmap.intensityBucket(1), 1);
  expect(YearHeatmap.intensityBucket(2), 2);
  expect(YearHeatmap.intensityBucket(3), 3);
});

test('cellsFor most recent is today', () {
  final today = DateTime(2026, 5, 13);
  final cells = YearHeatmap.cellsFor(today, {});
  expect(cells.last, today);
});
```

### Manualni acceptance

1. /stats nacte se < 1s i pri 200+ tasku.
2. Heatmap zobrazi mesicni labely nad + tydenni vlevo.
3. Tap na bunku s ukoly → bottom sheet, datum + ukoly.
4. Tap na prazdnou bunku → nic.
5. Streak header se zobrazi jen kdyz `user.streak > 0`.
6. Achievement grid pod heatmapou funguje.
7. Pomer kategorii pie pod achievementy.
8. Dark mode: bunky bgSubtle tmave, intensities respect theme.
9. Theme color switch (neon-ruzova): heatmap se prebarvi.
10. Compact: horizontal scroll heatmapy, fade indicator napravo.
11. Rozlozeny + widescreen: sidebar zustava, heatmap se vejde.

---

## 6. Co NENI v MVP

- **Per-habit mini-rows** pod heatmapou.
- **Year navigation** sipky (2025/2026/2027) — az pribyde data.
- **Pomer typu ukolu pie chart** — drop.
- **Bar chart XP za 7 dni** — drop, heatmap nahradi.
- **Tap na ukol v day-sheetu** → task detail — YAGNI.
- **Mesicni summary** ("brezen: 23 ukolu") nad mesicnimi label — moc detail.

---

## 7. Rollout (input pro writing-plans)

7 faz:

1. **Foundation:** `YearHeatmap` widget skeleton + intensityBucket / cellsFor + unit testy.
2. **Aggregation:** `tasksPerDay` helper + integrace s `_allTasks` (preda do widgetu).
3. **Visual polish:** mesicni / tydenni label, neo border + offset shadow.
4. **DayDetailSheet:** widget + helper.
5. **`stats_page.dart` refaktor:** drop 4 cards + bar + type pie. Pridat streak header. Pridat heatmap. Wire onCellTap.
6. **Layout responzivita:** widescreen 18px centered, compact 12px horizontal scroll + fade indicator.
7. **Empty / loading states:** new user 0 tasks → hint, loading → skeleton heatmap.

Phase-level review: 1-3 → review, 4-5 → review, 6-7 → final.

### Velikost

- ~10-15 commitu
- ~3-4 hodiny prace
- Tests: 5 unit testu + 11 manualni acceptance bodu
