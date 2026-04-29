import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    await _firestore.collection('users').doc(_uid).update({
      'nickname': nickname,
    });
  }

  Future<void> toggleNotifications(bool value) async {
    await _firestore.collection('users').doc(_uid).update({
      'notificationsEnabled': value,
    });
  }

  Stream<DocumentSnapshot> notificationsSettingStream() {
    return _firestore.collection('users').doc(_uid).snapshots();
  }
}
