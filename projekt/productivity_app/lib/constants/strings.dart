abstract final class Strings {
  // Task type labels
  static const typeDaily = 'Denní';
  static const typeWeekly = 'Týdenní';
  static const typeMonthly = 'Měsíční';

  // Buttons
  static const cancel = 'Zrušit';
  static const delete = 'Smazat';
  static const save = 'Uložit';
  static const createTask = 'Vytvořit úkol';
  static const confirm = 'Potvrdit';
  static const reject = 'ODMÍTNOUT';
  static const confirmUpper = 'POTVRDIT';

  // Status
  static const statusCompleted = 'Splněno';
  static const statusRejected = 'Odmítnuto';
  static const statusPending = 'Čeká na potvrzení';
  static const statusResend = 'Odeslat znovu';

  // Dialog titles
  static const newTask = 'Nový úkol';
  static const editTask = 'Upravit úkol';
  static const deleteTask = 'Smazat úkol?';
  static const deleteTaskConfirm = 'Opravdu chceš smazat';
  static const rejectTask = 'Odmítnout úkol';
  static const rejectReason = 'Proč odmítáš tento úkol?';
  static const rejectReasonLabel = 'Důvod odmítnutí';
  static const rejectReasonHint = 'Např. Fotka neodpovídá úkolu...';
  static const deleteAccount = 'Smazat účet?';
  static const deleteAccountWarning =
      'Tato akce je nevratná. Přijdeš o všechny úkoly, XP a mince.';
  static const deleteAccountButton = 'SMAZAT NAVŽDY';

  // Form hints
  static const taskTitleHint = 'Co chceš splnit?';
  static const taskTitleLabel = 'Název úkolu';
  static const taskTypeLabel = 'Typ úkolu';
  static const taskCodeLabel = 'Kód úkolu';
  static const habitTitleLabel = 'Název návyku';
  static const habitTypeLabel = 'Typ návyku';

  // Empty states — short, confident voice (no exclamation marks, no "klikni na").
  static const noTasksTitle = 'Žádné úkoly.';
  static const noTasksSubtitle = 'Přidej první a vydělej XP.';
  static const noNotifications = 'Klid. Nikdo se neozývá.';
  static const expiringNotification = 'Úkol vyprší zítra.';
  static const noStatsData = 'Zatím nuly. Splníš úkol, přijdou čísla.';

  // Snackbar messages
  static const photoSaved = 'Důkaz uložen!';
  static const photoTooLarge = 'Obrázek je moc velký. Zkus jiný.';
  static const photoRequired = 'Musíš nejdřív vyfotit důkaz!';
  static const taskResetOk = 'Úkol připraven k novému odeslání!';
  static const taskResetError = 'Chyba při resetu úkolu.';
  static const taskConfirmed = 'Potvrzeno! Odměna připsána.';
  static const taskConfirmError = 'Chyba při potvrzování. Zkuste to znovu.';
  static const taskRejected = 'Úkol byl odmítnut.';
  static const taskRejectError = 'Chyba při odmítání. Zkuste to znovu.';
  static const taskNotFound =
      'Úkol s tímto kódem nenalezen nebo už byl potvrzen.';
  static const taskSearchError = 'Chyba při hledání: Zkuste to znovu.';
  static const rejectReasonRequired = 'Zadej důvod odmítnutí';
  static const fillAllFields = 'Vyplňte všechna pole';
  static const loginError = 'Chyba přihlášení';
  static const accountDeleted = 'Účet byl úspěšně smazán.';
  static const accountDeleteError =
      'Chyba mazání. Zkuste se odhlásit a znovu přihlásit.';

  // Task card
  static const takePhoto = 'Vyfotit důkaz';
  static const changePhoto = 'Změnit fotku';
  static const editTaskAction = 'Upravit úkol';
  static const deleteTaskAction = 'Smazat úkol';
  static const reasonPrefix = 'Důvod: ';
  static const noPhoto = 'Bez fotky';

  // Navigation / AppBar
  static const notifications = 'Notifikace';
  static const stats = 'Statistiky';
  static const confirmCode = 'Potvrdit kód';
  static const settings = 'Nastavení';
  static const logout = 'Odhlásit se';
  static const readAll = 'Přečíst vše';
  static const today = 'Dnes';
  static const confirmTask = 'Potvrzení úkolu';
  static const confirmingTask = 'Potvrzuješ úkol:';
  static const confirmAnother = 'Potvrdit další';
  static const goBack = 'Zpět';
  static const confirmedHeadline = 'Hotovo!';
  static const confirmedSubtitle = 'Odměna byla připsána kamarádovi.';

  // Brand
  static const appName = 'MOTIVATOR';
  static const tagline = 'Potvrzeno = odměněno.';

  // Categories
  static const categoriesLabel = 'KATEGORIE';
  static const filterAll = 'Vše';
  static const filterByType = 'Typ';
  static const filterByCategory = 'Kategorie';
  static const noCategoryLabel = 'Bez kategorie';

  // Login
  static const login = 'Přihlášení';
  static const register = 'Registrace';
  static const loginButton = 'Přihlásit';
  static const registerButton = 'Registrovat';
  static const googleLogin = 'Přihlásit přes Google';
  static const noAccountPrompt = 'Nemáš účet? Registrace';
  static const hasAccountPrompt = 'Máš účet? Přihlášení';
  static const nicknameLabel = 'Tvoje přezdívka';
  static const emailLabel = 'E-mail';
  static const passwordLabel = 'Heslo';

  // Settings
  static const darkMode = 'Tmavý režim';
  static const layoutMode = 'Rozložení';
  static const layoutCompact = 'Kompaktní';
  static const layoutSpread = 'Rozložený';
  static const colorTheme = 'Barevný motiv';
  static const notificationsTitle = 'Notifikace';
  static const notificationsSubtitle =
      'Přijímat notifikace při potvrzení/odmítnutí úkolu';
  static const deleteAccountAction = 'Smazat účet';
  static const deleteAccountSubtitle = 'Kompletně odstraní všechna data';
  static const profileSection = 'Profil';
  static const nicknameSetting = 'Přezdívka';
  static const changeNicknameTitle = 'Změnit přezdívku';
  static const nicknameTooShort = 'Přezdívka musí mít aspoň 2 znaky.';
  static const nicknameUpdated = 'Přezdívka aktualizována.';
  static const nicknameUpdateError = 'Nepodařilo se uložit přezdívku.';
  static const logoutAction = 'Odhlásit se';
  static const logoutSubtitle = 'Vrátíš se na přihlašovací obrazovku';
  static const logoutConfirm = 'Opravdu se chceš odhlásit?';
  static const aboutAppTitle = 'O aplikaci';
  static const aboutAppCopy =
      'Motivátor je gamifikovaný plánovač. Splníš úkol, kamarád potvrdí, ty bereš XP.';
  static const aboutAppVersion = 'Verze';

  // Stats
  static const totalTasks = 'Celkem úkolů';
  static const completedTasks = 'Splněno';
  static const thisWeek = 'Tento týden';
  static const thisMonth = 'Tento měsíc';
  static const bestDay = 'Nejlepší den';
  static const xpLast7Days = 'XP za posledních 7 dní';
  static const taskTypeRatio = 'Poměr typů úkolů';
  static const streakLabel = 'Série';
  static const heatmapLess = 'méně';
  static const heatmapMore = 'více';
  static const uncategorizedLine = 'Bez kategorie';
  static const noCategorizedTasks = 'Zatím žádné kategorizované úkoly.';

  // Rewards
  static String rewardText(int xp, int coins) {
    final coinWord = coins == 1
        ? 'Mince'
        : (coins >= 2 && coins <= 4 ? 'Mince' : 'Mincí');
    return 'Odměna: $xp XP | $coins $coinWord';
  }

  // Day names
  static const dayNames = {
    1: 'Pondělí',
    2: 'Úterý',
    3: 'Středa',
    4: 'Čtvrtek',
    5: 'Pátek',
    6: 'Sobota',
    7: 'Neděle',
  };

  // Habits
  static const habit = 'Návyk';
  static const habits = 'Návyky';
  static const habitsMine = 'Moje návyky';
  static const newHabit = 'Nový návyk';
  static const habitActionsTooltip = 'Akce';
  static const weeklyHabitDayHint = 'Týdenní návyk = přesně jeden den v týdnu.';
  static const repeatTask = 'Opakovat pravidelně';
  static const recurrenceEveryday = 'Každý den';
  static const recurrenceWeekdays = 'Všední dny';
  static const recurrenceCustom = 'Vlastní';
  static const recurrenceLabel = 'Opakování';
  static const chooseDays = 'Vyber dny';
  static const habitStreak = 'Série návyku';
  static const habitRecord = 'rekord';
  static const editHabitOrInstance = 'Upravit jen tento úkol, nebo celý návyk?';
  static const thisOnly = 'Jen tento';
  static const wholeHabit = 'Celý návyk';
  static const pauseHabit = 'Pozastavit';
  static const resumeHabit = 'Aktivovat';
  static const deleteHabit = 'Smazat návyk';
  static const editHabit = 'Upravit návyk';
  static const deleteHabitConfirm = 'Smaže všechny budoucí instance. Minulé zůstanou.';
  static const noHabitsTitle = 'Žádné návyky.';
  static const noHabitsSubtitle = 'Klepni na + dole vpravo.';
  static const rewardTierWarning = 'Pozor: častá frekvence + měsíční tier = hodně XP.';

  static const weekdayShort = {
    1: 'Po', 2: 'Út', 3: 'St', 4: 'Čt', 5: 'Pá', 6: 'So', 7: 'Ne',
  };

  // Uspechy (achievements)
  static const achievementsHeader = 'ÚSPĚCHY';
  static const achievementEmptyHint = 'Splni něco neobvyklého a uvidí se.';
  static const achievementFilterAll = 'vše';
  static const achievementFilterSituational = 'situační';
  static const achievementFilterLore = 'tituly';
  static const achievementFilterAnti = 'anti';
  static const achievementFilterMilestone = 'mety';
  static const achievementUnlockedAt = 'Odemknuto';
  static const achievementSetAsTitle = 'NASADIT JAKO TITUL';
  static const achievementRemoveTitle = 'SUNDAT TITUL';
  static const achievementNotifTitle = 'NOVÝ ÚSPĚCH';
  static const achievementYourTitle = 'TVŮJ TITUL';
  static const achievementOpenStats = 'OTEVŘÍT STATISTIKY';
  static String achievementCounter(int unlocked, int total) =>
      '$unlocked / $total odhaleno';
  static String achievementUnlockToast(String title) =>
      'Nový úspěch: $title';

  // Friends
  static const profileTitle = 'Profil';
  static const openProfileSemantic = 'Otevřít profil';
  static const friendActivityHeader = 'AKTIVITA KAMARÁDŮ';
  static const friendActivityEmpty = 'Zatím tu nic není. Tvoji kamarádi musí něco odemknout.';
  static String friendActivityUnlocked(String achievementTitle) =>
      '— $achievementTitle';
  static const lastWeekHeader = 'PŘEDCHOZÍ TÝDEN';
  static const lastWeekNobody = 'Nikdo se neukázal. Tichý týden.';
  static String lastWeekWinnerLine(String nick, int xp) =>
      '$nick vyhrál s $xp XP';
  static String lastWeekYourScore(int xp) => 'Ty: $xp XP';

  // Global leaderboard
  static const globalLeaderboardHeader = 'TOP 20 TENTO TÝDEN';
  static const globalLeaderboardEmpty =
      'Zatím se nikdo nepřihlásil k veřejnému žebříčku.';
  static const globalLeaderboardOptInHint =
      'Zapni v Nastavení „Být k nalezení" — bez toho nejsi na globálu vidět.';

  // Browser web notifications
  static const browserNotifTitle = 'Push v prohlížeči';
  static const browserNotifSubtitle =
      'Notifikace skrz okno prohlížeče, dokud máš záložku otevřenou.';
  static const browserNotifGranted = 'Povoleno. Zkus si vyfotit důkaz.';
  static const browserNotifDenied =
      'Zakázáno v prohlížeči. Změň v ikoně zámku v adresním řádku.';
  static const browserNotifUnsupported = 'Tenhle prohlížeč to neumí.';
  static const browserNotifEnable = 'Povolit';
  static const browserNotifTestTitle = 'MOTIVATOR';
  static const browserNotifTestBody = 'Push notifikace fungují.';

  // Discovery
  static const discoverableTitle = 'Být k nalezení';
  static const discoverableSubtitle =
      'Ostatní tě najdou podle přezdívky a můžou tě přidat.';
  static const findFriendsTitle = 'Najít kamaráda';
  static const findFriendsHint = 'Zadej přezdívku…';
  static const findFriendsNoResults = 'Nikdo takový. Zkus jinou přezdívku.';
  static const findFriendsTooShort = 'Napiš aspoň 2 znaky.';
  static const findFriendsAdd = 'Přidat';
  static const findFriendsLevel = 'Lvl';
  static const friendsHeader = 'KAMARÁDI';
  static const inviteHeader = 'TVŮJ INVITE';
  static const shareInvite = 'Sdílet pozvánku';
  static const qrInvite = 'QR';
  static const qrDialogTitle = 'Sken pozvánky';
  static const qrDialogHint = 'Naskenuj telefonem kamaráda pro připojení.';
  static const close = 'Zavřít';
  static const regenerateInvite = 'Regenerovat';
  static const addFriendAction = 'Přidat kamaráda';
  static const inviteShareText = 'Čau! Přidej mě na Motivátoru. Otevři tenhle odkaz:\n';
  static const inviteScreenTitle = 'Pozvánka';
  static const inviteAddPromptPrefix = 'Přidat ';
  static const inviteAddPromptSuffix = ' jako kamaráda?';
  static const inviteAddButton = 'Přidat';
  static const inviteOwnCode = 'Tohle je tvůj vlastní invite. Sdílej ho s kamarády.';
  static const inviteAlreadyFriendSuffix = 'už je tvůj kamarád.';
  static const inviteNotFound = 'Pozvánka nenalezena. Možná byla zrušena.';
  static const friendAddedToast = 'Přidáno do kamarádů.';
  static const friendAddError = 'Chyba při přidávání kamaráda.';
  static const removeFriendAction = 'Odstranit z kamarádů';
  static const removeFriendConfirm = 'Odstranit z kamarádů?';
  static const noFriendsYet = 'Zatím žádné. Sdílej svou pozvánku.';
  static const leaderboardHeader = 'KAMARÁDI TENTO TÝDEN';
  static const leaderboardEmpty = 'Přidej kamaráda abys viděl žebříček.';
  static const xpThisWeekShort = 'XP tento týden';

  // Friend profile (read-only view)
  static const friendProfileTitle = 'Profil kamaráda';
  static const friendStatsHeader = 'STATISTIKY';
  static const friendNotFound = 'Profil nenalezen.';
  static const friendStatLevel = 'Level';
  static const friendStatCompleted = 'Splněno úkolů';
  static const friendStatWeekly = 'Tento týden';
  static const friendStatCoins = 'Mince';
  static const friendStatAchievements = 'Úspěchy';
  static const friendStatStreak = 'Série';

  /// Formats a day count with Czech pluralization (1 den / 2-4 dny / 5+ dní).
  static String dayPlural(int n) {
    if (n == 1) return '$n den';
    if (n >= 2 && n <= 4) return '$n dny';
    return '$n dní';
  }

  // Notification copy
  static const friendPendingTitlePrefix = ' čeká na potvrzení';
  static const friendAddedTitleSuffix = ' — nový kamarád';
  static const notifSectionToday = 'DNES';
  static const notifSectionYesterday = 'VČERA';
  static const notifSectionThisWeek = 'TENTO TÝDEN';
  static const notifSectionOlder = 'STARŠÍ';

  // Stats refactor
  static const lastYearHeader = 'TVOJE AKTIVITA';
  static const categoryRatio = 'POMĚR KATEGORIÍ';
  static String streakLine(int current) {
    final unit = current == 1 ? 'den' : (current >= 2 && current <= 4 ? 'dny' : 'dní');
    return 'Série: $current $unit';
  }
}
