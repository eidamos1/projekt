# MOTIVATOR

**Gamifikovaná aplikace na produktivitu** — vytvoříš si úkol, splníš ho, vyfotíš důkaz a pošleš ho kamarádovi k potvrzení. Kamarád ověří splnění přes odkaz, čímž ti odemkne XP, mince, level-up a bonus za sérii. Návyky generují opakující se úkoly, žebříček porovnává týdenní výkon mezi kamarády.

🔗 **Živá verze:** https://calendar-mot.web.app

Postaveno na **Flutteru + Firebase**, web jako primární platforma (běží i na Androidu, iOS, Windows, macOS).

---

## Co aplikace umí

### Úkoly a kalendář
- Tvorba denních / týdenních / měsíčních úkolů s kategoriemi (Práce, Osobní, Sport, Studium, Domácnost, Zdraví, Kreativita, Jiné)
- Kalendářní přehled (`table_calendar`) s českou lokalizací a filtrováním podle kategorií
- Fotodůkaz splnění — fotka se komprimuje při pořízení a ukládá přímo do Firestore

### Potvrzování přes kamarády
- Každý úkol má 6místný kód. Kamarád otevře potvrzovací odkaz, zadá kód → spustí se odměna
- Deep linking přes vlastní schéma (`adamapp://confirm?code=…`) i webové URL
- Pasivní „feed kamarádů" — po nahrání fotky dostanou kamarádi notifikaci s kódem k potvrzení

### Gamifikace
- **XP / mince / levely** odstupňované podle typu úkolu (denní 10 XP, týdenní 50 XP, měsíční 200 XP)
- **Série (streaky)** — uživatelská i samostatná série pro každý návyk, bonusy na 7/30/100 dnech
- **15 úspěchů** s vlastním hlasem místo generických „splň 10/50/100 úkolů" — situační (Noční sova), tituly (Pátečnízí hrdina), anti-úspěchy i mety. Každý má konkrétní důvod existovat.
- Odemknutí = řádek v in-app notifikacích, žádné blokující popupy ani konfety

### Návyky
- Opakující se úkoly (každý den / pracovní dny / vlastní dny) generované na 30 dnů dopředu
- Integrované do kalendáře jako normální úkol s indikátorem `↻`, ne ve vlastním odděleném světě
- Samostatná série a nejdelší série per návyk

### Kamarádi a žebříček
- Pozvánkový odkaz s oboustranným potvrzením + QR kód
- Vyhledávání podle přezdívky (opt-in `discoverable`)
- **Týdenní žebříček** (XP Po–Ne) mezi kamarády + globální top-20
- **Aktivita kamarádů** (feed odemčených úspěchů) a **vítěz minulého týdne** na profilu

### Statistiky
- Roční heatmapa (53×7) jako hlavní vizuál obrazovky
- Metrické karty (série / splněno / nejlepší den) a koláčový graf poměru kategorií (`fl_chart`)

### Ostatní
- Přihlášení e-mailem/heslem + Google Sign-In
- Volitelné barevné téma (neon paleta), persistované přes `SharedPreferences`
- Web push notifikace (foreground, browser Notifications API)

---

## Design

Vyhraněný **neobrutalismový** jazyk — žádná generická „AI dashboard" estetika:
- 2px černé borders, tvrdé offset stíny bez blur, malé radii
- Tmavý podklad + neon akcenty (zelená / růžová / žlutá / cyan / oranžová)
- Font Space Grotesk, CAPS akcentace u labelů
- Veškeré UI texty v češtině s diakritikou

---

## Tech stack

| Vrstva | Technologie |
|--------|-------------|
| Framework | Flutter 3.9+ (Material 3) |
| Backend | Firebase: Auth, Cloud Firestore, Hosting |
| Stav | Provider (téma) + StreamBuilder (realtime data) |
| Grafy | `fl_chart` |
| Deep linking | `app_links` |
| Ostatní | `google_sign_in`, `image_picker`, `share_plus`, `qr_flutter`, `google_fonts` |

---

## Architektura

```
lib/
├── main.dart          # vstup, ThemeProvider, route table, deep linky
├── pages/             # celoobrazovkové stránky (login, kalendář, stats, profil, …)
├── models/            # datové třídy (Task, Habit, UserData, Achievement, …) s fromMap/toMap
├── services/          # Firestore + Auth wrappery — jediná vrstva, co sahá na Firestore
├── widgets/           # znovupoužitelné komponenty (task_card, xp_bar, year_heatmap, …)
├── constants/         # paleta, neo téma, herní konfig, české stringy, registr úspěchů
└── utils/             # date/week helpery, invite kódy, formátování
```

**Klíčový princip:** stránky volají služby, služby vlastní čtení/zápis do Firestore. Stránky se na Firestore nesahají přímo. Logika úspěchů jsou čisté predikátové funkce nad snapshotem dat → testovatelné bez Firestore.

---

## Spuštění

```bash
# Závislosti
flutter pub get

# Vývoj na Chrome (primární cíl)
flutter run -d chrome

# Produkční web build
flutter build web

# Nasazení na Firebase Hosting
firebase deploy --only hosting
```

Konfigurace Firebase je v `lib/firebase_options.dart` (generováno) a `firebase.json` / `.firebaserc`.

---

## Testy

```bash
flutter test       # 143 testů, zelené
flutter analyze    # bez chyb
```

Testy pokrývají čistou logiku (modely, predikáty úspěchů, výpočty sérií, helpery). Firestore I/O se nemockuje — pokrytí je na úrovni doménové logiky.

---

## Datový model (Firestore)

```
users/{uid}/
  ├── nickname, xp, coins, level, streak, weeklyXp, inviteCode, …
  ├── tasks/{taskId}/        # title, type, date, code, completed, imageBase64, categories[]
  ├── habits/{habitId}/      # recurrence, streak, longestStreak, active
  ├── achievements/{achId}/  # unlockedAt
  ├── friends/{friendUid}/   # oboustranné hrany
  └── notifications/{notifId}/

taskCodes/{code}/    → userId, taskId    # globální index pro potvrzovací flow
userInvites/{code}/  → userId            # globální index pozvánek
```

---

*Solo side-projekt. Pro detaily architektury viz `CLAUDE.md`, návrhové dokumenty v `docs/plans/`.*
