class UserData {
  final String id;
  final String nickname; // Nové: Přezdívka
  final int xp;
  final int coins;
  final int level;

  UserData({
    required this.id,
    required this.nickname,
    this.xp = 0,
    this.coins = 0,
    this.level = 1,
  });

  factory UserData.fromMap(String id, Map<String, dynamic> data) {
    return UserData(
      id: id,
      nickname: data['nickname'] ?? 'Hráč', // Defaultní jméno
      xp: data['xp'] ?? 0,
      coins: data['coins'] ?? 0,
      level: data['level'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'xp': xp,
      'coins': coins,
      'level': level,
    };
  }
}