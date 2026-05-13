# Friends + Leaderboard — Design

**Date:** 2026-05-13
**Status:** Design approved, ready for implementation plan
**Phase:** v2 push, fáze 4 (poslední). Předchozí fáze (habits, achievements, stats refactor) jsou na `main` a deployed.

---

## Cíl

Sociální vrstva pro Motivator. Uživatel si přidá kamarády invite linkem (mutual handshake), uvidí týdenní XP žebříček, dostane notifikace když kamarád nahraje úkol k potvrzení a může ho v jednom kroku potvrdit bez kopírování kódu.

## Klíčová rozhodnutí

| Decision | Pick | Reason |
|----------|------|--------|
| Discovery | **Invite link** (persistent code) | Privacy-first, žádný globální search, sedí k existující share-link flow |
| Friendship | **Mutual handshake** | Recipient confirm screen → oba souhlasí, jako confirm-task pattern |
| Metric | **Týdenní XP** (Mon-Sun, lokální čas) | Fair pro nově přidané, motivuje stále, Duolingo-league pattern |
| UI placement | **Hybrid** | `/profile` page (klik na profile chip) + kompaktní widget v `/stats` |
| Confirm integrace | **Passive friend-feed** | Friend nahraje fotku → ostatním notif s thumbnail → tap = confirm bez kódu. Existující kód-share zůstává pro non-friends |
| Reset model | **Lazy** v `confirmTask` transakci | Žádný cron/Cloud Function, kontrola `weeklyXpWeekStart` při každém confirmu |

## Data model

### Nová pole na `users/{uid}/`

```
inviteCode: 'A3F9K2P7'                  // 8 znaků, [A-Z0-9], unique, generován lazily
weeklyXp: int                           // XP nasbírané v aktuálním týdnu
weeklyXpWeekStart: 'yyyy-MM-dd'         // pondělí týdne, ke kterému weeklyXp patří
```

### Nové (sub)kolekce

```
users/{uid}/friends/{friendUid}/
  ├── nickname (denormalizovaný snapshot pro list display bez extra read)
  ├── addedAt: 'yyyy-MM-dd HH:mm'
  // při unfriend: smazat OBA edge (uid→friendUid + friendUid→uid)

userInvites/{inviteCode}/
  └── userId                            // globální index inviteCode → uid
```

### Změny existujících kolekcí

- `users/{uid}/notifications/{nid}` — přidat nové typy `friend_added` a `friend_pending`. Stávající `confirmed`/`rejected`/`expiring`/`achievement` zůstávají.

## Flows

### Discovery & add friend

1. **Sender** na `/profile` → `Sdilet pozvanku`:
   - Pokud `inviteCode` neexistuje, generuj (8 znaků, retry při collision) + zapiš `userInvites/{code} = {userId: uid}`.
   - Otevři Web Share API s linkem `https://calendar-mot.web.app/#/friend?code=A3F9K2P7`.
2. **Recipient** klikne link → `FriendInviteScreen`:
   - Lookup `userInvites/{code}` → `userId` → načti `users/{userId}` pro avatar + nickname.
   - Edge case `code == myInviteCode` → "Tohle je tvuj vlastni invite. Sdilej ho s kamarady." + Zpet.
   - Edge case už friend → "tralala uz je tvuj kamarad." + Zpet.
   - Edge case invalid → "Pozvanka nenalezena. Mozna byla zrusena." + Zpet.
   - Jinak: "Pridat tralala jako kamarada?" + [Zrusit] [Pridat].
3. **Pridat** → batched write transakce:
   - `users/{me}/friends/{senderUid} = {nickname, addedAt}`
   - `users/{senderUid}/friends/{me} = {nickname, addedAt}`
   - `users/{senderUid}/notifications/friend_added_{me} = {type, fromNickname, createdAt, read: false}` (deterministic doc id pro idempotenci)
4. Navigace na `/profile` + success snackbar.

### Regenerate code

- Tlačítko `Regenerovat` v `/profile`. Smaže `userInvites/{oldCode}`, vygeneruj nový, zapiš. Starý link už nikde nefunguje (žádný notif).

### Unfriend

- Long-press friend card → bottom sheet "Odstranit X z kamaradu?" → potvrzení.
- Transakce smaže obě edges. Žádný notif (silent).

### Týdenní XP — update & read

**Write** v `TaskService.confirmTask` transakci, ihned po existujícím `xp` increment:

```dart
final mondayStr = formatDate(_mondayOf(DateTime.now()));
final stale = (userData['weeklyXpWeekStart'] as String?) != mondayStr;
final newWeeklyXp = (stale ? 0 : (userData['weeklyXp'] as int? ?? 0)) + reward.xp;
tx.update(userRef, {
  // ...existing xp/coins/level/streak updates
  'weeklyXp': newWeeklyXp,
  'weeklyXpWeekStart': mondayStr,
});
```

Helper `_mondayOf(DateTime d)` vrací Po 00:00 pro libovolné datum.

**Read** v leaderboard (FriendService):

```dart
Stream<List<FriendRank>> leaderboardStream() async* {
  // 1. Načti vlastní friends list (small N, typicky <20)
  // 2. Pro každého friend.uid + sebe: snapshot users/{uid}
  //    weeklyXp je 0 pokud weeklyXpWeekStart != thisMonday (stale check)
  // 3. Seřaď DESC podle weeklyXp, vrať List<FriendRank>{rank, uid, nickname, weeklyXp, streak, isMe}
}
```

### Passive friend-feed (confirm flow)

- V `task_card.dart` v `_savePhoto` po úspěšném zápisu `imageBase64`:
  - Pro každého friend v `users/{me}/friends/`: zapiš `users/{friend.uid}/notifications/friend_pending_{taskId}` = `{type: 'friend_pending', fromNickname, fromUid, taskId, taskTitle, code, thumbnailBase64?, createdAt, read: false}`.
  - Doc id deterministický → idempotentní při re-upload (přepíše).
- V Notifikace listu friend_pending má zelený border + thumbnail vlevo + text "Tralala caka na potvrzeni: huh". Tap → `/confirm?code=XXXXXX` (existující page).
- **Cleanup**: při `TaskService.confirmTask` / `rejectTask` / task expire — smazat `friend_pending_{taskId}` ze všech friend inboxů. Implementace: read `users/{owner}/friends/` → pro každého `friendUid` delete `users/{friendUid}/notifications/friend_pending_{taskId}`. Bezpečné failover (404 = už smazáno).

## UI

### `/profile` page (nová route)

Aktivace: tap na profile chip (`UserChip`) v AppBaru `/calendar` a `/stats`. Layout (mobile):

```
[← Zpet]   Profil

  ╔════════════════════════════════╗
  ║ [Avatar T]                     ║
  ║                                ║
  ║   tralala                      ║
  ║   [Aktivni titul: ...] (pokud) ║
  ║   level 1 · 10 XP · 5 minci    ║
  ║   🔥 1 dni                     ║
  ╚════════════════════════════════╝

  TVUJ INVITE
  ┌──────────────────────────┐
  │ A3F9K2P7                 │
  └──────────────────────────┘
  [Sdilet]  [Regenerovat]

  KAMARADI (3)
  [+ Pridat kamarada]   (otevře Web Share API přes vlastní invite)

  ○ tralala2  🔥 5  · 320 XP tento tyden     1.
  ○ jonas     🔥 2  · 110 XP tento tyden     2.
  ○ honza     🔥 0  · 0 XP tento tyden       3.

  (long-press → "Odstranit z kamaradu")
```

Empty state pro `KAMARADI`: "Zatim zadne. Sdilej svou pozvanku."

### Compact widget v `/stats`

Pozice: pod metric kartami (Splneno/Serie/Nejlepsi den), nad heatmapou. Renderovat **pouze pokud friends >= 1** (jinak skrýt).

```
KAMARADI TENTO TYDEN
┌────────────────────────────────────────┐
│ 1. tralala2    320 XP                  │
│ 2. tralala     250 XP  ← ty            │
│ 3. jonas       110 XP                  │
│ + 2 dalsi  →                            │
└────────────────────────────────────────┘
```

Tap na `+ N dalsi` nebo na widget header → naviguje na `/profile`. Tap na řádek = no-op v MVP (read-only profil view = post-MVP).

### `FriendInviteScreen` (route `/friend?code=...`)

```
[← Zpet]   Pozvanka

  [Avatar T]

   tralala
   level 1 · 🔥 1

   Pridat tralala jako kamarada?

  [Zrusit]      [Pridat]
```

Edge state copy:
- vlastní kód: "Tohle je tvuj vlastni invite. Sdilej ho s kamarady."
- už friend: "tralala uz je tvuj kamarad."
- invalid: "Pozvanka nenalezena. Mozna byla zrusena."

### Notifikace UI

`friend_pending` notif card:
- Levá: 40x40 thumbnail z `thumbnailBase64` (cropped) — fallback ikona
- Body: "**Tralala** caka na potvrzeni" + sub: "huh · 50 XP"
- Border color: AppColors.neonGreen (akce required)
- Tap → `/confirm?code=XXXXXX`

`friend_added` notif card:
- Ikona person_add
- Body: "**Tralala** te pridal jako kamarada"
- Border: AppColors.neonCyan (friendly)
- Tap → `/profile` (scroll na nového friend)

## Architektura

### Nový service: `lib/services/friend_service.dart`

```dart
class FriendService {
  Stream<UserData> myProfileStream();
  Stream<String> myInviteCodeStream();              // generates lazily if missing
  Future<void> regenerateInviteCode();
  Future<UserData?> resolveInvite(String code);     // for FriendInviteScreen
  Future<void> addFriend(String otherUid);          // mutual transaction
  Future<void> removeFriend(String otherUid);       // mutual transaction
  Stream<List<UserData>> friendsStream();           // own friends subcollection
  Stream<List<FriendRank>> leaderboardStream();     // self + friends, sorted DESC by weeklyXp
  Future<void> notifyFriendsOfPendingTask({
    required String taskId,
    required String taskTitle,
    required String code,
    String? thumbnailBase64,
  });
  Future<void> cleanupFriendPendingNotifs(String taskId);
}
```

### Nový model: `lib/models/friend_rank.dart`

```dart
class FriendRank {
  final int rank;
  final String uid;
  final String nickname;
  final int weeklyXp;
  final int streak;
  final bool isMe;
  // computed: stale check vs current Monday
}
```

### Změny existujících servis

- `TaskService.confirmTask` — přidat weekly XP update v transakci (viz výše)
- `TaskService.confirmTask` + `rejectTask` — po commit volat `FriendService.cleanupFriendPendingNotifs(taskId)`
- `TaskService.uploadProof` (nebo equivalent v `task_card.dart` `_savePhoto`) — po úspěchu volat `FriendService.notifyFriendsOfPendingTask(...)`
- `AuthService.deleteAccount` — projít vlastní friends, pro každého smazat reverse edge
- `UserService.updateNickname` — po update zapsat denormalizovaný nickname snapshot do `users/{friendUid}/friends/{me}` pro každého friend (best-effort)

### Routes

Přidat do `main.dart`:
```dart
'/profile': (_) => const ProfilePage(),
'/friend': (_) => const FriendInviteScreen(),  // čte ?code= z URL fragmentu
```

## Firestore rules

```
match /users/{userId} {
  // existing rules + povolit číst `inviteCode`, `nickname`, `xp`, `weeklyXp`, `weeklyXpWeekStart`,
  // `streak`, `level`, `activeTitle` ostatním auth users (potřebné pro FriendInviteScreen + leaderboard).
  // Citlivá pole (`notificationsEnabled`, atd.) zůstávají owner-only.
  allow read: if request.auth != null;
  allow update: if request.auth.uid == userId;
}

match /users/{userId}/friends/{friendId} {
  allow read: if request.auth.uid == userId;
  // Vytvoření allow jen pokud volající je sám sebe NEBO friendId (mutual write transakce)
  allow create: if request.auth != null
                  && (request.auth.uid == userId || request.auth.uid == friendId);
  allow delete: if request.auth.uid == userId || request.auth.uid == friendId;
}

match /userInvites/{code} {
  allow read: if request.auth != null;
  allow create: if request.auth.uid == request.resource.data.userId;
  allow delete: if request.auth.uid == resource.data.userId;
}

match /users/{userId}/notifications/{nid} {
  allow read: if request.auth.uid == userId;
  allow create: if request.auth != null
                  && (request.auth.uid == userId
                      || exists(/databases/$(database)/documents/users/$(userId)/friends/$(request.auth.uid)));
  allow update, delete: if request.auth.uid == userId
                          || (resource.data.fromUid is string
                              && request.auth.uid == resource.data.fromUid);  // owner of source can cleanup
}
```

## Error handling & edge cases

| Edge case | Handling |
|-----------|----------|
| Otevření vlastního invite | FriendInviteScreen detect → "Tohle je tvuj vlastni invite." copy + Zpet |
| Už friends | Detect → "tralala uz je tvuj kamarad." copy + Zpet |
| Invalid/expired kód | `userInvites/{code}` doc neexistuje → "Pozvanka nenalezena." |
| Regenerate code | Old code → delete, new code → write. Old link silently breaks (no notif) |
| Friend smaže účet | `deleteAccount` iteruje vlastní friends, smaže reverse edges (best-effort) |
| Týdenní reset edge | Lazy v `confirmTask` — stale `weeklyXpWeekStart` → reset to 0 + add reward |
| Duplicate friend_pending | Deterministic doc id `friend_pending_{taskId}` → re-upload přepíše stejný doc |
| Race na add 2x | Idempotent `set` write — žádný error |
| Notif owner smaže fotku | `cleanupFriendPendingNotifs` — pokud notif už neexistuje, no-op |
| Nickname change | Best-effort update denormalizovaného snapshotu v `friends/{me}` u všech friends |

## Testing

### Unit (target ≥10)

- `_mondayOf(DateTime)` — středa, neděle, pondělí, půlnoc edge cases
- `WeeklyXpReset.shouldReset(currentMonday, storedWeekStart)` — true pokud != , false jinak
- `LeaderboardRank.sortAndFindMe(entries, myUid)` — vrací seřazené + můj index
- `InviteCodeGenerator` — délka 8, charset, retry na collision
- `Notif.dedupKey` — `friend_pending_{taskId}` deterministic

### Integration smoke (test pres mock / fake Firestore nebo manual playwright)

- Add friend full flow: A generuje kód → B opens URL → confirm → both have edges + A has notif
- Self-invite → no-add screen
- Unfriend → both edges removed
- DeleteAccount → reverse edges cleaned up
- ConfirmTask → friend_pending notif smazána ze všech friend inboxů

## Build sequence (7 fází)

| # | Fáze | Acceptance |
|---|------|------------|
| 1 | **Foundation** — data model migration (lazy on first read), `FriendService` skeleton, Firestore rules, `_mondayOf` helper + tests | `flutter test` green, rules deployed bez break stávajících flowů |
| 2 | **Invite + add friend** — `/profile` skeleton, share invite, `FriendInviteScreen`, mutual write transakce, `friend_added` notif | Playwright: 2 účty → A sdílí, B přidá, oba vidí navzájem |
| 3 | **Friend list view** — friend cards v `/profile`, unfriend long-press s confirm sheet | Playwright: unfriend → friend zmizí z obou stran |
| 4 | **Weekly XP plumbing** — `TaskService.confirmTask` update, lazy reset, unit tests, denormalized nickname sync | Confirm → `weeklyXp` += reward, fresh week → reset to 0 |
| 5 | **Leaderboard** — `/profile` friend list seřazený DESC podle weeklyXp + kompaktní widget v `/stats` | Playwright: confirm → leaderboard updates real-time |
| 6 | **Passive friend-feed** — `friend_pending` notif při photo upload, cleanup při confirm/expire | Playwright: A nahraje fotku → B vidí notif → tap → confirm page → cleanup |
| 7 | **Polish** — copy, empty states, edge cases (self-invite, already-friends, regenerate), error toasty | Manual review checklist |

Fáze 1-3 jsou foundation, 4-6 jsou velue. 7 je tuning. Doporučená cadence: review po každé fázi.

## YAGNI (NEJSOU v MVP)

- Search friends podle nicku
- Globální leaderboard
- Friend's profil read-only view (tap na řádek = no-op)
- Block / report
- Friend Activity feed ("tralala odemkl uspech")
- Push notifications (in-app stačí)
- Týdenní winner snapshot ("posledni tyden vyhral honza")
- All-time XP leaderboard tab
- Achievement count ranking

## Otevřené otázky

Žádné — všechna klíčová rozhodnutí ujasněna a schválena.
