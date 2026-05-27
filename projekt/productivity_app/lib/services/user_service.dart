import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friend_service.dart';

class UserService {
  static UserService? _instance;
  factory UserService() => _instance ??= UserService._();
  UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Uzivatel neni prihlasen — nelze pristoupit k uid.');
    }
    return user.uid;
  }

  Stream<DocumentSnapshot> profileStream() {
    return _firestore.collection('users').doc(_uid).snapshots();
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    return doc.data();
  }

  Future<void> updateNickname(String nickname) async {
    // Keep a lowercase denormalized copy for case-insensitive prefix search.
    // Trim+toLower client-side; the query in friend_service uses the same.
    await _firestore.collection('users').doc(_uid).update({
      'nickname': nickname,
      'nicknameLower': nickname.trim().toLowerCase(),
    });
    // Propagate to all friends' denormalized snapshots (best-effort).
    await FriendService().propagateNicknameUpdate(nickname);
  }

  Future<void> toggleNotifications(bool value) async {
    await _firestore.collection('users').doc(_uid).update({
      'notificationsEnabled': value,
    });
  }

  Future<void> setDiscoverable(bool value) async {
    await _firestore.collection('users').doc(_uid).update({
      'discoverable': value,
    });
  }

  Stream<DocumentSnapshot> notificationsSettingStream() {
    return _firestore.collection('users').doc(_uid).snapshots();
  }
}
