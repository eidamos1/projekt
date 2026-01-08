// models/user.dart
class UserData {
  final String id;
  final int xp;
  final int coins;
  final int level;

  UserData({required this.id, this.xp = 0, this.coins = 0, this.level = 1});

  // Přečtení z Firestore dokumentu
  factory UserData.fromMap(String id, Map<String, dynamic> data) {
    return UserData(
      id: id,
      xp: data['xp'] ?? 0,
      coins: data['coins'] ?? 0,
      level: data['level'] ?? 1,
    );
  }

  // Převedení na mapu pro zápis do Firestore
  Map<String, dynamic> toMap() {
    return {
      'xp': xp,
      'coins': coins,
      'level': level,
    };
  }
}
