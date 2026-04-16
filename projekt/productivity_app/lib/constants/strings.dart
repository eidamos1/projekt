abstract final class Strings {
  // Task type labels
  static const typeDaily = 'Denni';
  static const typeWeekly = 'Tydenni';
  static const typeMonthly = 'Mesicni';
  static const typeDailyAccented = 'Denn\u00ed';
  static const typeWeeklyAccented = 'T\u00fddenn\u00ed';
  static const typeMonthlyAccented = 'M\u011bs\u00ed\u010dn\u00ed';

  // Buttons
  static const cancel = 'Zrusit';
  static const delete = 'Smazat';
  static const save = 'Ulozit';
  static const createTask = 'Vytvorit ukol';
  static const confirm = 'Potvrdit';
  static const reject = 'ODMITNOUT';
  static const confirmUpper = 'POTVRDIT';

  // Status
  static const statusCompleted = 'Splneno';
  static const statusRejected = 'Odmitnuto';
  static const statusPending = 'Ceka na potvrzeni';
  static const statusResend = 'Odeslat znovu';

  // Dialog titles
  static const newTask = 'Novy ukol';
  static const editTask = 'Upravit ukol';
  static const deleteTask = 'Smazat ukol?';
  static const deleteTaskConfirm = 'Opravdu chces smazat';
  static const rejectTask = 'Odmitnout ukol';
  static const rejectReason = 'Proc odmitas tento ukol?';
  static const rejectReasonLabel = 'Duvod odmiteni';
  static const rejectReasonHint = 'Napr. Fotka neodpovida ukolu...';
  static const deleteAccount = 'Smazat ucet?';
  static const deleteAccountWarning =
      'Tato akce je nevratna. Prijdete o vsechny ukoly, XP a mince.';
  static const deleteAccountButton = 'SMAZAT NAVZDY';

  // Form hints
  static const taskTitleHint = 'Co chces splnit?';
  static const taskTitleLabel = 'Nazev ukolu';
  static const taskTypeLabel = 'Typ ukolu';
  static const taskCodeLabel = 'Kod ukolu';

  // Empty states
  static const noTasksTitle = 'Zadne ukoly pro tento den';
  static const noTasksSubtitle = 'Klikni na + a pridej novy ukol!';
  static const noNotifications = 'Zadne notifikace';
  static const expiringNotification = 'Ukol vyprsí zitra!';
  static const noStatsData = 'Zadna data k zobrazeni';

  // Snackbar messages
  static const photoSaved = 'Dukaz ulozen!';
  static const photoTooLarge = 'Obrazek je moc velky. Zkus jiny.';
  static const photoRequired = 'Musis nejdriv vyfotit dukaz!';
  static const taskResetOk = 'Ukol pripraven k novemu odeslani!';
  static const taskResetError = 'Chyba pri resetu ukolu.';
  static const taskConfirmed = 'Potvrzeno! Odmena pripsana.';
  static const taskConfirmError = 'Chyba pri potvrzovani. Zkuste to znovu.';
  static const taskRejected = 'Ukol byl odmitnut.';
  static const taskRejectError = 'Chyba pri odmitani. Zkuste to znovu.';
  static const taskNotFound =
      'Ukol s timto kodem nenalezen nebo uz byl potvrzen.';
  static const taskSearchError = 'Chyba pri hledani: Zkuste to znovu.';
  static const rejectReasonRequired = 'Zadej duvod odmiteni';
  static const fillAllFields = 'Vyplnte vsechna pole';
  static const loginError = 'Chyba prihlaseni';
  static const accountDeleted = 'Ucet byl uspesne smazan.';
  static const accountDeleteError =
      'Chyba mazani. Zkuste se odhlasit a znovu prihlasit.';

  // Task card
  static const takePhoto = 'Vyfotit dukaz';
  static const changePhoto = 'Zmenit fotku';
  static const editTaskAction = 'Upravit ukol';
  static const deleteTaskAction = 'Smazat ukol';
  static const reasonPrefix = 'Duvod: ';
  static const noPhoto = 'Bez fotky';

  // Navigation / AppBar
  static const notifications = 'Notifikace';
  static const stats = 'Statistiky';
  static const confirmCode = 'Potvrdit kod';
  static const settings = 'Nastaveni';
  static const logout = 'Odhlasit';
  static const readAll = 'Precist vse';
  static const today = 'Dnes';
  static const confirmTask = 'Potvrzeni ukolu';
  static const confirmingTask = 'Potvrzujes ukol:';

  // Login
  static const login = 'Prihlaseni';
  static const register = 'Registrace';
  static const loginButton = 'Prihlasit';
  static const registerButton = 'Registrovat';
  static const googleLogin = 'Google Prihlaseni';
  static const noAccountPrompt = 'Nemas ucet? Registrace';
  static const hasAccountPrompt = 'Mas ucet? Prihlaseni';
  static const nicknameLabel = 'Tvoje prezdivka';
  static const emailLabel = 'E-mail';
  static const passwordLabel = 'Heslo';

  // Settings
  static const darkMode = 'Tmavy rezim';
  static const layoutMode = 'Rozložení';
  static const layoutCompact = 'Kompaktní';
  static const layoutSpread = 'Rozložený';
  static const colorTheme = 'Barevný motiv';
  static const notificationsTitle = 'Notifikace';
  static const notificationsSubtitle =
      'Prijmat notifikace pri potvrzeni/odmiteni ukolu';
  static const deleteAccountAction = 'Smazat ucet';
  static const deleteAccountSubtitle = 'Kompletne odstrani vsechna data';

  // Stats
  static const totalTasks = 'Celkem ukolu';
  static const completedTasks = 'Splneno';
  static const thisWeek = 'Tento tyden';
  static const thisMonth = 'Tento mesic';
  static const bestDay = 'Nejproduktivnejsi den';
  static const xpLast7Days = 'XP za poslednich 7 dni';
  static const taskTypeRatio = 'Pomer typu ukolu';

  // Rewards
  static String rewardText(int xp, int coins) =>
      'Odmena: $xp XP | $coins Minci';

  // Day names
  static const dayNames = {
    1: 'Pondeli',
    2: 'Utery',
    3: 'Streda',
    4: 'Ctvrtek',
    5: 'Patek',
    6: 'Sobota',
    7: 'Nedele',
  };
}
