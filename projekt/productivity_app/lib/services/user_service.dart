import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

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
}
