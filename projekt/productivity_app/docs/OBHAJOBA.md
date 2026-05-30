# MOTIVATOR — podklady k obhajobě

Tahák pro obhajobu: o čem mluvit, jak obhájit rozhodnutí, co odpovědět na záludné otázky. Živá verze: https://calendar-mot.web.app

---

## 1. O čem to je (elevator pitch — 20 s)

> Motivator je gamifikovaná appka na produktivitu. Vytvoříš si úkol, splníš ho, **vyfotíš důkaz a pošleš ho kamarádovi k potvrzení**. Teprve když ho kamarád ověří, dostaneš XP, mince a levely. Tím se řeší hlavní problém běžných to-do appek — že si je člověk odškrtává sám sobě a nikdo ho nekontroluje. Sociální tlak = motivace.

Klíčový diferenciátor: **potvrzování kamarádem** + **achievementy s vlastním vtipem** místo generických „splň 10 úkolů".

---

## 2. Tech stack (a proč)

| Vrstva | Volba | Proč |
|--------|-------|------|
| Frontend | **Flutter** (Material 3) | jeden kód → web, Android, iOS, desktop |
| Backend | **Firebase** (Auth, Firestore, Hosting) | serverless — žádný vlastní server, rychlý vývoj |
| Stav | **Provider** + **StreamBuilder** | téma přes Provider, realtime data z Firestore přes streamy |
| Grafy | `fl_chart` | heatmapa + koláč na statistikách |
| Deep linking | `app_links` | potvrzovací a pozvánkové odkazy |
| Další | `image_picker`, `qr_flutter`, `share_plus`, `google_sign_in` | foto, QR pozvánky, sdílení |

Primární platforma = **web**, nasazený na Firebase Hosting.

---

## 3. Architektura (jak to drží pohromadě)

**Vrstvy:**
- `lib/pages/` — obrazovky (UI + StreamBuilder)
- `lib/services/` — **jediná vrstva, co sahá na Firestore** (auth, task, habit, user, friend, achievement…)
- `lib/models/` — datové třídy s `fromMap`/`toMap`
- `lib/widgets/`, `lib/constants/`, `lib/utils/` — komponenty, paleta/téma, čistá logika

> **Pravidlo:** stránky nikdy nesahají na Firestore přímo, jen přes službu. To drží I/O na jednom místě a dělá logiku testovatelnou.

**Datový model (Firestore):**
```
users/{uid}/ … nickname, xp, coins, level, streak, weeklyXp, inviteCode
  ├── tasks/{id}       title, type, date, code (6 míst), completed, imageBase64, categories[]
  ├── habits/{id}      recurrence, streak, longestStreak
  ├── achievements/{id} unlockedAt
  ├── friends/{uid}    oboustranné hrany
  └── notifications/{id}
taskCodes/{code}   → {userId, taskId}   globální index pro potvrzování
userInvites/{code} → userId             globální index pozvánek
```

**Herní pravidla** (`GameConfig`): denní 10 XP/5 mincí, týdenní 50/20, měsíční 200/100. Level = `XP ÷ 100 + 1`. Bonus za sérii na 7/30/100 dnech (50/200/1000 XP).

**Achievementy** — 15 kusů jako **čisté predikátové funkce** nad snapshotem dat (`lib/constants/achievements.dart`). Testovatelné bez Firestore.

---

## 4. Klíčová rozhodnutí (a obhajoba)

| Rozhodnutí | Odůvodnění |
|-----------|------------|
| **Serverless (Firebase), žádný vlastní backend** | Pro rozsah projektu rychlejší a bez správy serveru. Realtime zdarma přes Firestore streamy. |
| **Fotky jako base64 přímo ve Firestore** | Žádná druhá služba (Cloud Storage) = jednodušší. Foto se komprimuje na 500 px / 40 % / max 750 KB, vejde se do 1 MB limitu dokumentu. **Tradeoff: neškáluje na hodně velkých fotek** — ale na ně tahle appka necílí. |
| **Potvrzování přes 6místný kód** | Sociální *trust model* — kód dáš jen kamarádovi, kterého chceš za ověřovatele. Globální index `taskCodes/{code}` se vyhne skenování napříč uživateli. |
| **Neobrutalismus** (tlusté borders, neon, hard shadows) | Záměrně vyhraněný styl, aby appka nevypadala jako generická šablona. |
| **Achievementy se situačním vtipem** | „Noční sova", „Mañana? Tak ne dnes." — každý má konkrétní spouštěč, ne arbitrární číslo. |

---

## 5. Slabá místa + připravené odpovědi ⭐ (nejdůležitější část)

Tyhle otázky pravděpodobně přijdou. Řekni je **první**, než je vytáhne komise — z útoku se stane důkaz, že o tom přemýšlíš.

**Q: Pravidla Firestore jsou hodně volná — `allow update: if request.auth != null`. Nemůže si kdokoli přidat XP?**
> Ano, je to vědomá slabina. Potvrzení úkolu probíhá **z klienta kamaráda**, takže pravidla musí povolit zápis XP do cizího dokumentu. Bez serverové logiky to jinak nejde. **Správné řešení = Cloud Function** (callable), která transakci provede serverově s kontrolou oprávnění a klientský zápis zakáže. Je to první bod v „budoucí práci". Pro MVP a sociální appku mezi kamarády je to přijatelný kompromis.

**Q: Proč base64 ve Firestore a ne Cloud Storage?**
> Jednoduchost — žádná druhá služba, žádné signed URL / CORS. Fotky jsou komprimované a capnuté na 750 KB, vejdou se do 1MB doc limitu. Vědomý tradeoff: na velký objem fotek by se přešlo na Storage.

**Q: Jak je to s testy?**
> 148 unit testů na **čistou logiku** — predikáty achievementů, výpočty sérií, datové helpery, prefix bounds vyhledávání. Firestore I/O se nemockuje. Další krok by byly integrační testy přes Firebase emulator.

**Q: Co když je uživatel offline / akce selže?**
> Streamy se samy obnoví, transakce potvrzení dělá všechna čtení před zápisy (požadavek Firestore). Achievement eval se dožene při dalším loginu (auth-state restore). Neplatný kód → graceful hláška, žádný pád.

**Q: Web push notifikace?**
> Zatím **foreground-only** přes browser Notifications API (když je záložka otevřená). Plné background push by chtělo FCM + service worker — záměrně mimo rozsah.

**Q: Bezpečnost potvrzovacího kódu?**
> 6 míst = trust model, ne kryptografická bariéra. Kód sdílíš jen s kamarádem. Pozvánkové kódy mají 8 znaků z neambiguózní abecedy (bez 0/O/1/I/L), generované `Random.secure()`.

---

## 6. Demo skript (krok po kroku)

Plynulý tok, který vypráví celý příběh. Ideálně 2 účty (v druhém okně/anonymním režimu).

1. **Login** → ukázat brand, přihlásit hlavní účet.
2. **Kalendář** → „tady je dnešek, level bar, mince". Klepnout **➕** → vytvořit úkol (kategorie Sport), ukázat denní/týdenní/měsíční.
3. **Vyfotit důkaz** → nahrát foto → úkol je „Čeká na potvrzení".
4. **Druhý účet (kamarád)** → dostane notifikaci „čeká na potvrzení" → klepne → **kód předvyplněný** + fotka → **POTVRDIT**.
5. **Zpět hlavní účet** → naskočilo XP, mince, případně **level-up** a **achievement** (řádek v notifikacích, žádný blokující popup).
6. **Statistiky** → roční **heatmapa** (hero vizuál), metriky, **žebříček kamarádů** podle týdenního XP, koláč kategorií.
7. **Profil** → pozvánka / **QR kód**, seznam kamarádů, aktivita kamarádů, vítěz minulého týdne.
8. **Návyky** → ukázat opakovaný úkol s `↻` (integrace, ne separátní svět).
9. **Nastavení → Jak to funguje** → **průvodce** (5 karet — shrnuje celý koncept).

Tip: mít účet **předem naplněný** daty (kamarádi, leaderboard, odemčené achievementy), ať to vypadá živě.

---

## 7. Časté otázky komise + odpovědi

- **„Kolik je to práce / jak dlouho?"** → Postaveno po fázích: úkoly+kalendář → návyky → achievementy → statistiky → kamarádi+žebříček → discovery+push. Každá fáze má návrhový dokument v `docs/plans/`.
- **„Co bys udělal jinak?"** → Confirm flow do Cloud Function (bezpečnost), foto do Storage při škálování, integrační testy přes emulator.
- **„Proč Flutter a ne nativně / React?"** → Jeden kód pro web i mobil, silný UI layer, rychlá iterace. Firebase má pro Flutter první-třídní SDK.
- **„Jak řešíš opakované úkoly?"** → Návyk generuje instance na 30 dní dopředu a okno se prodlužuje při každém otevření kalendáře. Instance = normální úkol s indikátorem `↻`.
- **„Lokalizace?"** → Celé UI v češtině s diakritikou, `cs` locale přes `flutter_localizations`, datumy přes `initializeDateFormatting('cs')`.

---

## 8. Budoucí práce (ukazuje rozhled)

- **Confirm flow do Cloud Function** — serverová integrita odměn (hlavní bezpečnostní vylepšení).
- Fotky do **Cloud Storage** při růstu objemu.
- **Background push** přes FCM + service worker.
- **Integrační testy** přes Firebase emulator.
- Blokování / nahlášení uživatele, i18n framework.

---

## 9. Čísla projektu

- **148** unit testů (zelené), `flutter analyze` čistý
- **15** achievementů, **8** kategorií úkolů, **7** barevných motivů
- Cílové platformy: web (nasazeno), Android, iOS, Windows, macOS
- Firebase projekt `calendar-mot`, hosting `https://calendar-mot.web.app`
