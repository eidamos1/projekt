# Stats Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promenit `/stats` z dashboard-page na heatmap-hero stranku — rocni heatmapa (53×7 grid s intenzitou = pocet splnenych ukolu) jako vrchol, pod tim achievementy + pomer kategorii.

**Architecture:** Statelessovy `YearHeatmap` widget bere `Map<String, int>` (`yyyy-MM-dd → count`) a callback `onCellTap`. `StatsPage` agreguje `_allTasks` na klientu, preda mapa do widgetu, tap → `DayDetailSheet` (neo bottom sheet s listem tasku daneho dne). Drop 4 stat cards, bar chart 7 dni, pomer typu pie.

**Tech Stack:** Flutter 3.9+, existujici `NeoTheme` styling, `intl` pres `cs` locale, `fl_chart` (zustava pro pomer kategorii pie).

**Design reference:** `docs/plans/2026-05-13-stats-refactor-design.md`

**Testing strategy:**
- **Unit tests (TDD)** pro pure logiku: `YearHeatmap.intensityBucket`, `YearHeatmap.cellsFor`, `tasksPerDay` helper. Pouzit `flutter_test`.
- **Manual verification** pro UI rendering, scroll, dark mode, theme switch, layout responzivita.

**Commit discipline:** Commit po kazde tasku, zpravy v stejnem stylu jako existujici. **Co-Authored-By trailer** na kazdem commitu: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. HEREDOC pro multi-line.

**Review batching:** Po fazi 3 → review. Po fazi 5 → review. Po fazi 7 → final review.

---

## Phase 1: Foundation (`YearHeatmap` skeleton + pure logika)

### Task 1: `intensityBucket` + unit testy

**Files:**
- Create: `lib/widgets/year_heatmap.dart`
- Create: `test/widgets/year_heatmap_test.dart`

**Step 1: Write failing tests**

`test/widgets/year_heatmap_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/widgets/year_heatmap.dart';

void main() {
  group('YearHeatmap.intensityBucket', () {
    test('returns 0 for count 0', () {
      expect(YearHeatmap.intensityBucket(0), 0);
    });

    test('returns count for 1..3', () {
      expect(YearHeatmap.intensityBucket(1), 1);
      expect(YearHeatmap.intensityBucket(2), 2);
      expect(YearHeatmap.intensityBucket(3), 3);
    });

    test('returns 4 for 4+', () {
      expect(YearHeatmap.intensityBucket(4), 4);
      expect(YearHeatmap.intensityBucket(10), 4);
      expect(YearHeatmap.intensityBucket(100), 4);
    });
  });
}
```

**Step 2: Run — should fail**

```
flutter test test/widgets/year_heatmap_test.dart
```

Expected: FAIL — `year_heatmap.dart` neexistuje.

**Step 3: Implement skeleton**

`lib/widgets/year_heatmap.dart`:

```dart
import 'package:flutter/material.dart';

class YearHeatmap extends StatelessWidget {
  final Map<String, int> tasksPerDay;
  final String? firstTaskDate;
  final void Function(DateTime date) onCellTap;

  const YearHeatmap({
    super.key,
    required this.tasksPerDay,
    required this.onCellTap,
    this.firstTaskDate,
  });

  static int intensityBucket(int count) {
    if (count <= 0) return 0;
    if (count >= 4) return 4;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // skeleton, real impl in Task 4
  }
}
```

**Step 4: Run — should pass**

```
flutter test test/widgets/year_heatmap_test.dart
```

Expected: PASS (5 tests).

**Step 5: Commit**

```bash
git add lib/widgets/year_heatmap.dart test/widgets/year_heatmap_test.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap skeleton + intensityBucket

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `cellsFor` — 53×7 grid generator

**Files:**
- Modify: `lib/widgets/year_heatmap.dart`
- Modify: `test/widgets/year_heatmap_test.dart`

**Step 1: Write failing tests**

Pridat do existujici `void main()`:

```dart
group('YearHeatmap.cellsFor', () {
  test('returns 53 weeks × 7 days = 371 cells', () {
    final cells = YearHeatmap.cellsFor(DateTime(2026, 5, 13));
    expect(cells.length, 53 * 7);
  });

  test('most recent cell is today', () {
    final today = DateTime(2026, 5, 13);
    final cells = YearHeatmap.cellsFor(today);
    expect(cells.last.year, today.year);
    expect(cells.last.month, today.month);
    expect(cells.last.day, today.day);
  });

  test('first cell is approximately 52 weeks ago', () {
    final today = DateTime(2026, 5, 13);
    final cells = YearHeatmap.cellsFor(today);
    final first = cells.first;
    final diff = today.difference(first).inDays;
    expect(diff, greaterThanOrEqualTo(52 * 7));
    expect(diff, lessThan(53 * 7));
  });
});
```

**Step 2: Run — should fail**

```
flutter test test/widgets/year_heatmap_test.dart
```

Expected: FAIL — `cellsFor` neexistuje.

**Step 3: Implement**

V `lib/widgets/year_heatmap.dart` pridat static method nad `build`:

```dart
/// Vrati 53 * 7 = 371 DateTime hodnot. Posledni napravo = today, predchozi
/// rolling-back po dnech. Nejlevejsi sloupec = pred ~52 tydny.
static List<DateTime> cellsFor(DateTime today) {
  final lastCell = DateTime(today.year, today.month, today.day);
  final cells = <DateTime>[];
  // Zacni 53*7 - 1 dni v minulosti, jdi az do dneska
  for (int i = 53 * 7 - 1; i >= 0; i--) {
    cells.add(lastCell.subtract(Duration(days: i)));
  }
  return cells;
}
```

**Step 4: Run — should pass**

```
flutter test test/widgets/year_heatmap_test.dart
```

Expected: PASS (8 tests total).

**Step 5: Commit**

```bash
git add lib/widgets/year_heatmap.dart test/widgets/year_heatmap_test.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap.cellsFor returns rolling 371-day grid

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `tasksPerDay` helper

**Files:**
- Create: `lib/utils/stats_helpers.dart`
- Create: `test/utils/stats_helpers_test.dart`

**Step 1: Write failing tests**

`test/utils/stats_helpers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/models/task.dart';
import 'package:productivity_app/utils/stats_helpers.dart';

Task _t(String date, {bool completed = true}) => Task(
      id: 'x', title: 'x', type: TaskType.daily,
      date: date, xp: 10, coins: 5, code: '111111',
      completed: completed,
    );

void main() {
  group('tasksPerDay', () {
    test('counts only completed tasks', () {
      final result = tasksPerDay([
        _t('2026-05-12'),
        _t('2026-05-12'),
        _t('2026-05-12', completed: false),
        _t('2026-05-13'),
      ]);
      expect(result['2026-05-12'], 2);
      expect(result['2026-05-13'], 1);
    });

    test('returns empty map for empty input', () {
      expect(tasksPerDay([]), <String, int>{});
    });

    test('returns empty map when all uncompleted', () {
      final result = tasksPerDay([_t('2026-05-12', completed: false)]);
      expect(result, <String, int>{});
    });
  });
}
```

**Step 2: Run — should fail**

```
flutter test test/utils/stats_helpers_test.dart
```

Expected: FAIL — file neexistuje.

**Step 3: Implement**

`lib/utils/stats_helpers.dart`:

```dart
import '../models/task.dart';

/// Vrati Map<yyyy-MM-dd → pocet splnenych ukolu>.
Map<String, int> tasksPerDay(List<Task> tasks) {
  final counts = <String, int>{};
  for (final t in tasks) {
    if (!t.completed) continue;
    counts.update(t.date, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}
```

**Step 4: Run — should pass**

```
flutter test test/utils/stats_helpers_test.dart
```

Expected: PASS (3 tests).

**Step 5: Commit**

```bash
git add lib/utils/stats_helpers.dart test/utils/stats_helpers_test.dart
git commit -m "$(cat <<'EOF'
feat: tasksPerDay helper for heatmap aggregation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

> ## REVIEW CHECKPOINT — Phase 1 (Foundation)
>
> Spustit `superpowers:requesting-code-review`. Klice:
> - `flutter test` zelene (vsechny pure-logic testy).
> - `flutter analyze` 0 errors.
> - `cellsFor` poradi `cells.last == today` neprehazene.

---

## Phase 2: Visual layer (YearHeatmap render + style)

### Task 4: Render 53×7 grid s barvy

**Files:**
- Modify: `lib/widgets/year_heatmap.dart`

**Step 1: Implement `build`**

Nahradit `return const SizedBox.shrink();` v `build`:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primary = Theme.of(context).colorScheme.primary;
  final mediaWidth = MediaQuery.of(context).size.width;
  final isWide = mediaWidth >= 1080;
  final cellSize = isWide ? 18.0 : 12.0;
  final spacing = 2.0;

  final cells = cellsFor(DateTime.now());
  final firstCellDate = firstTaskDate != null
      ? DateTime.parse(firstTaskDate!)
      : null;

  // 53 sloupcu × 7 radek
  final columns = <Widget>[];
  for (int week = 0; week < 53; week++) {
    final rows = <Widget>[];
    for (int day = 0; day < 7; day++) {
      final idx = week * 7 + day;
      if (idx >= cells.length) {
        rows.add(SizedBox(width: cellSize, height: cellSize));
        continue;
      }
      final date = cells[idx];
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = tasksPerDay[dateStr] ?? 0;
      final bucket = intensityBucket(count);
      final preSignup = firstCellDate != null && date.isBefore(firstCellDate);

      Color color;
      if (preSignup) {
        color = Colors.transparent;
      } else if (bucket == 0) {
        color = isDark ? const Color(0xFF1A1A24) : const Color(0xFFE8E8E8);
      } else {
        final alpha = 0.25 * bucket; // 0.25, 0.5, 0.75, 1.0
        color = primary.withValues(alpha: alpha);
      }

      rows.add(GestureDetector(
        onTap: count > 0 ? () => onCellTap(date) : null,
        child: Container(
          width: cellSize,
          height: cellSize,
          margin: EdgeInsets.symmetric(vertical: spacing / 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
    }
    columns.add(Padding(
      padding: EdgeInsets.only(right: spacing),
      child: Column(children: rows),
    ));
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: columns),
  );
}
```

**Step 2: Manual verify**

`flutter run -d chrome --web-port 8080`. Otevri `/stats`. Heatmap jeste neni v `stats_page.dart`, takze tohle se otestuje v Phase 3 Task 7. Tady jen `flutter analyze`:

```
flutter analyze lib/widgets/year_heatmap.dart
```

Expected: 0 errors.

**Step 3: Run tests**

```
flutter test
```

Expected: vsechny green (98+ tests).

**Step 4: Commit**

```bash
git add lib/widgets/year_heatmap.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap render — 53x7 grid s intensity barvami

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Mesicni + tydenni labely

**Files:**
- Modify: `lib/widgets/year_heatmap.dart`

**Step 1: Implement labely**

Wrap grid v `Column` co ma nahore mesicni labely a vlevo tydenni:

```dart
@override
Widget build(BuildContext context) {
  // ...predchozi logika do `columns` zustava...

  // Mesicni labely nad sloupcem kde dany mesic zacina.
  final monthLabels = <Widget>[];
  String? prevMonth;
  for (int week = 0; week < 53; week++) {
    final firstDayIdx = week * 7;
    if (firstDayIdx >= cells.length) {
      monthLabels.add(SizedBox(width: cellSize + spacing));
      continue;
    }
    final firstDate = cells[firstDayIdx];
    final month = _monthLabel(firstDate.month);
    final showLabel = prevMonth != month && firstDate.day <= 7;
    monthLabels.add(SizedBox(
      width: cellSize + spacing,
      child: Text(
        showLabel ? month : '',
        style: TextStyle(
          fontSize: 9,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    ));
    if (showLabel) prevMonth = month;
  }

  // Tydenni labely vlevo (Po, St, Pa).
  final weekLabels = <Widget>[];
  const weekDayNames = ['Po', '', 'St', '', 'Pa', '', ''];
  for (int day = 0; day < 7; day++) {
    weekLabels.add(SizedBox(
      height: cellSize + spacing,
      child: Text(
        weekDayNames[day],
        style: TextStyle(
          fontSize: 9,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    ));
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(children: monthLabels),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: weekLabels),
            const SizedBox(width: 4),
            Row(children: columns),
          ],
        ),
      ],
    ),
  );
}

static String _monthLabel(int m) {
  const labels = ['', 'led', 'uno', 'bre', 'dub', 'kve', 'cer',
      'cvc', 'srp', 'zar', 'rij', 'lis', 'pro'];
  return labels[m];
}
```

**Step 2: Verify**

```
flutter analyze
flutter test
```

**Step 3: Commit**

```bash
git add lib/widgets/year_heatmap.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap mesicni + tydenni labely

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Neo styling + outer border

**Files:**
- Modify: `lib/widgets/year_heatmap.dart`

**Step 1: Wrap v NeoTheme container**

Pridat import:

```dart
import '../constants/neo_theme.dart';
import '../constants/app_colors.dart';
```

Wrap finalni `SingleChildScrollView` v `Container` s `NeoTheme.cardDecoration`:

```dart
return Container(
  padding: const EdgeInsets.all(NeoTheme.spaceSm),
  decoration: NeoTheme.cardDecoration(isDark: isDark),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Column(...),
  ),
);
```

**Step 2: Verify**

```
flutter analyze
flutter test
```

**Step 3: Commit**

```bash
git add lib/widgets/year_heatmap.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap neo container styling

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

> ## REVIEW CHECKPOINT — Phase 2 (Visual layer)
>
> Pred Phase 3: code review tedu na 4-6 nedoresenych UI nuanci (alpha values, label spacing, mobile compact).

---

## Phase 3: DayDetailSheet

### Task 7: `DayDetailSheet` widget + helper

**Files:**
- Create: `lib/widgets/dialogs/day_detail_sheet.dart`

**Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/neo_theme.dart';
import '../../constants/task_categories.dart';
import '../../models/task.dart';
import '../../utils/context_extensions.dart';
import '../neo_bottom_sheet.dart';

void showDayDetailSheet(BuildContext context, DateTime date, List<Task> dayTasks) {
  showNeoBottomSheet<void>(
    context: context,
    children: [
      DayDetailSheet(date: date, tasks: dayTasks),
    ],
  );
}

class DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;

  const DayDetailSheet({super.key, required this.date, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final totalXp = tasks.fold<int>(0, (sum, t) => sum + t.xp);
    final dateLabel = DateFormat('EEEE, d. MMMM yyyy', 'cs').format(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NeoTheme.spaceLg, NeoTheme.spaceMd,
        NeoTheme.spaceLg, NeoTheme.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${tasks.length} ukolu \u00b7 $totalXp XP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: NeoTheme.spaceMd),
          ...tasks.map((t) => _DayTaskRow(task: t, isDark: isDark)),
        ],
      ),
    );
  }
}

class _DayTaskRow extends StatelessWidget {
  final Task task;
  final bool isDark;

  const _DayTaskRow({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (task.habitId != null) ...[
            const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.neonCyan),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (task.categories.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    children: task.categories
                        .map((k) => Categories.byKey(k))
                        .whereType<TaskCategory>()
                        .map((cat) => Text(
                              cat.label,
                              style: TextStyle(fontSize: 10, color: cat.color),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${task.xp} XP',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify**

```
flutter analyze lib/widgets/dialogs/day_detail_sheet.dart
flutter test
```

**Step 3: Commit**

```bash
git add lib/widgets/dialogs/day_detail_sheet.dart
git commit -m "$(cat <<'EOF'
feat: DayDetailSheet bottom sheet for heatmap cell tap

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4: Stats page refaktor

### Task 8: Pridat Strings.dart konstanty

**Files:**
- Modify: `lib/constants/strings.dart`

**Step 1: Append nove keys**

Pred posledni `}` v `Strings` class:

```dart
// Stats refactor
static const lastYearHeader = 'POSLEDNICH 365 DNI';
static const categoryRatio = 'POMER KATEGORII';
static String streakLine(int current, int record) =>
    'Serie: $current dni · rekord $record';
static String summaryLine(int splneno, int celkem, String? bestDay) =>
    bestDay == null
        ? 'Splneno $splneno · Celkem $celkem'
        : 'Splneno $splneno · Celkem $celkem · Nejlepsi den: $bestDay';
```

**Step 2: Verify**

```
flutter analyze
flutter test
```

**Step 3: Commit**

```bash
git add lib/constants/strings.dart
git commit -m "$(cat <<'EOF'
feat: stats refactor Strings keys (cs)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Refaktor `stats_page.dart` — drop stareho + zapojit heatmap

**Files:**
- Modify: `lib/pages/stats_page.dart`

Tohle je nejvetsi task — pojedme po krocich.

**Step 1: Add imports**

Na vrchol:

```dart
import '../utils/stats_helpers.dart';
import '../widgets/year_heatmap.dart';
import '../widgets/dialogs/day_detail_sheet.dart';
```

**Step 2: Drop unused imports / variables**

V `_StatsPageState`:
- Pri zustani `bestDay` computation reuse.
- Drop computations: `weekStart`, `thisWeekCompleted`, `thisMonthCompleted`, `dailyCount`, `weeklyCount`, `monthlyCount`, `xpPerDay` (cely block).
- Drop `_StatCard` widget z konce souboru.

**Step 3: Nahradit build body**

V `build` metoda po `if (_isLoading)`:

```dart
final completed = _allTasks.where((t) => t.completed).toList();
final completedCount = completed.length;
final total = _allTasks.length;

// Nejlepsi den (reuse logic)
final dayCount = <int, int>{};
for (final t in completed) {
  try {
    final d = parseDate(t.date);
    dayCount[d.weekday] = (dayCount[d.weekday] ?? 0) + 1;
  } catch (_) {}
}
String? bestDay;
if (dayCount.isNotEmpty) {
  final best = dayCount.entries.reduce((a, b) => a.value > b.value ? a : b);
  bestDay = Strings.dayNames[best.key];
}

// Heatmap data
final perDay = tasksPerDay(_allTasks);
final firstTask = _allTasks.isEmpty
    ? null
    : _allTasks
        .map((t) => t.date)
        .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

// Categorie counts
final categoryCounts = <String, int>{};
int uncategorizedCount = 0;
for (final t in _allTasks) {
  if (t.categories.isEmpty) {
    uncategorizedCount++;
  } else {
    for (final key in t.categories) {
      categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
    }
  }
}

final isDark = context.isDark;

return Scaffold(
  appBar: AppBar(title: const Text(Strings.stats)),
  body: ResponsiveLayout(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(NeoTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak header (user.streak from Firestore — needed!)
          // For now, hardcoded "0 dni" placeholder; wire to user doc in Task 10.
          // TODO: replace with StreamBuilder<DocumentSnapshot> on user doc.

          // Heatmap section header
          const Text(Strings.lastYearHeader, style: NeoTheme.subhead),
          const SizedBox(height: NeoTheme.spaceSm),
          YearHeatmap(
            tasksPerDay: perDay,
            firstTaskDate: firstTask,
            onCellTap: (date) {
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final dayTasks = _allTasks
                  .where((t) => t.completed && t.date == dateStr)
                  .toList();
              showDayDetailSheet(context, date, dayTasks);
            },
          ),
          const SizedBox(height: NeoTheme.spaceSm),
          Text(
            Strings.summaryLine(completedCount, total, bestDay),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: NeoTheme.spaceLg),

          // Achievements grid (existing)
          AchievementGrid(
            unlockedAtMap: _unlockedAtMap,
            totalCompletedTasks: completedCount,
            onTapCard: (ach) {
              final unlockedAt = _unlockedAtMap[ach.id];
              showAchievementDetailSheet(context, ach, unlockedAt);
            },
          ),

          // Pomer kategorii (existing pie)
          if (categoryCounts.isNotEmpty || uncategorizedCount > 0) ...[
            const SizedBox(height: NeoTheme.spaceLg),
            const Text(Strings.categoryRatio, style: NeoTheme.subhead),
            const SizedBox(height: NeoTheme.spaceSm),
            Container(
              decoration: NeoTheme.cardDecoration(isDark: isDark),
              padding: const EdgeInsets.all(NeoTheme.spaceMd),
              child: SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: [
                      ...categoryCounts.entries.map((e) {
                        final cat = Categories.byKey(e.key);
                        if (cat == null) return null;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: '${cat.label}\n${e.value}',
                          color: cat.color,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).whereType<PieChartSectionData>(),
                      if (uncategorizedCount > 0)
                        PieChartSectionData(
                          value: uncategorizedCount.toDouble(),
                          title: 'Bez kat.\n$uncategorizedCount',
                          color: const Color(0xFF8888AA),
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  ),
  bottomNavigationBar: const NeoBottomNav(currentIndex: 2),
);
```

**Step 4: Drop unused imports + `_StatCard` class na konci souboru**

Smazat:
- `import 'package:fl_chart/fl_chart.dart';` — pockej, jeste `PieChart` pro kategorii pouzivame. Necham.
- `import 'package:intl/intl.dart';` — pouzite uvnitr datepicker — hmm, ne, intl je v stats. Najit reference: pokud `intl/intl.dart` neni jiz pouzite, drop. (Pomer kategorii pie nepouziva intl.)
- `_StatCard` na konci souboru — smazat cely class.

**Step 5: Verify**

```
flutter analyze lib/pages/stats_page.dart
flutter test
```

Expected: 0 errors. Vsechny existujici testy green.

**Step 6: Commit**

```bash
git add lib/pages/stats_page.dart
git commit -m "$(cat <<'EOF'
feat: stats_page refactor — heatmap hero, drop 4 cards + bar + type pie

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Streak header (kdyz user.streak > 0)

**Files:**
- Modify: `lib/pages/stats_page.dart`

**Step 1: Add user stream**

Na vrchol `_StatsPageState` pridat:

```dart
int _userStreak = 0;
int _userLongestStreak = 0; // user-level — pokud existuje v user doc
```

V `_loadStats` po `final unlockedAtMap = ...`:

```dart
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid != null) {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() ?? {};
      _userStreak = data['streak'] ?? 0;
      // longestStreak je na habits, ne na user doc — predame 0 jako fallback.
      _userLongestStreak = data['longestStreak'] ?? _userStreak;
    }
  } catch (_) {}
}
```

**Step 2: Pridat streak header v build**

V `Column` pred `Strings.lastYearHeader`:

```dart
if (_userStreak > 0) ...[
  Container(
    padding: const EdgeInsets.symmetric(
        horizontal: NeoTheme.spaceMd, vertical: NeoTheme.spaceSm),
    decoration: BoxDecoration(
      color: AppColors.neonPink.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
      border: Border.all(
        color: AppColors.neonPink,
        width: NeoTheme.borderWidthThin,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_fire_department,
            color: AppColors.neonPink, size: 20),
        const SizedBox(width: 6),
        Text(
          Strings.streakLine(_userStreak, _userLongestStreak),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neonPink,
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: NeoTheme.spaceMd),
],
```

**Step 3: Verify**

```
flutter analyze
flutter test
```

**Step 4: Commit**

```bash
git add lib/pages/stats_page.dart
git commit -m "$(cat <<'EOF'
feat: stats streak header from user.streak

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

> ## REVIEW CHECKPOINT — Phase 4 (Stats page integration)
>
> Manualni test:
> - Otevri `/stats`, vidis heatmapu nahore.
> - Tap na bunku s 1+ uloky → bottom sheet otevre s datem + ukoly.
> - Tap na prazdnou bunku → nic.
> - Stary 4 stat cards / bar chart / type pie pryc.
> - Achievement grid pod heatmapou funguje.
> - Pomer kategorii pie pod tim.

---

## Phase 5: Polish a edge cases

### Task 11: Compact horizontal scroll fade indicator

**Files:**
- Modify: `lib/widgets/year_heatmap.dart`

**Step 1: Pridat fade overlay**

Wrap `SingleChildScrollView` v `Stack` s `Positioned` fade gradient napravo (jen kdyz compact):

```dart
final mediaWidth = MediaQuery.of(context).size.width;
final isWide = mediaWidth >= 1080;
// ... existing logic ...

final grid = SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Column(...),
);

if (isWide) return Container(decoration: NeoTheme.cardDecoration(isDark: isDark), padding: ..., child: grid);

// Compact: pridat fade na prave strane
return Container(
  decoration: NeoTheme.cardDecoration(isDark: isDark),
  padding: const EdgeInsets.all(NeoTheme.spaceSm),
  child: Stack(
    children: [
      grid,
      Positioned(
        right: 0, top: 0, bottom: 0,
        child: IgnorePointer(
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  isDark ? AppColors.cardDark : AppColors.cardLight,
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
```

**Step 2: Verify + commit**

```
flutter analyze
flutter test
git add lib/widgets/year_heatmap.dart
git commit -m "$(cat <<'EOF'
feat: YearHeatmap compact mode fade indicator

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Empty / loading states

**Files:**
- Modify: `lib/pages/stats_page.dart`

**Step 1: New-user empty state**

V `build` pred zobrazenim heatmapy:

```dart
if (_allTasks.isEmpty) {
  return Scaffold(
    appBar: AppBar(title: const Text(Strings.stats)),
    body: const EmptyState(
      icon: Icons.bar_chart_rounded,
      title: Strings.noStatsData,
    ),
    bottomNavigationBar: const NeoBottomNav(currentIndex: 2),
  );
}
```

(Empty state widget existuje — `lib/widgets/empty_state.dart`.)

Note: existujici copy `Strings.noStatsData = 'Zatim nuly. Splnis ukol, prijdou cisla.'` — fits perfectly.

**Step 2: Loading state (skeleton heatmap)**

`_isLoading` branch uz existuje (`CircularProgressIndicator`). Pokud chcete neo-styled skeleton: zatim YAGNI. Skip.

**Step 3: Verify + commit**

```
flutter analyze
flutter test
git add lib/pages/stats_page.dart
git commit -m "$(cat <<'EOF'
feat: stats empty state when no tasks

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

> ## FINAL REVIEW CHECKPOINT — Phases 1-5
>
> 1. `flutter test` all green (100+ tests).
> 2. `flutter analyze` 0 errors.
> 3. Manual acceptance via Playwright (po deployment):
>    - Login → /stats.
>    - Heatmapa nahore, vsechny bunky vidim.
>    - Tap na splneny den → sheet otevre.
>    - Tap na prazdnou → nic.
>    - Achievement grid funguje.
>    - Pomer kategorii pie.
>    - Switch dark mode → bunky bgSubtle tmavé.
>    - Switch theme color → bunky se prebarvi.
>    - Compact layout → horizontal scroll funguje, fade na prave strane.
>    - Rozlozeny + widescreen → 18px bunky, sidebar visible.
>    - New ucet (0 tasku) → empty state.

---

## Po dokonceni

1. Update memory `project_v2_push.md` (stats refactor DONE, dalsi krok friends/leaderboard).
2. Merge feat branch nebo deploy directly.
3. Pristi v2 faze: friends + leaderboard.

---

## Yagni reminders

Co NEpridavat behem MVP:
- Per-habit mini-rows pod heatmapou.
- Year navigation sipky (2025/2026/2027) — az pribyde data.
- Tap-na-ukol → task detail v day sheetu.
- Mesicni summary ("brezen: 23 ukolu") nad mesicnimi label.
- CustomPaint optimalizace (jen pokud Column-grid je pomale).
