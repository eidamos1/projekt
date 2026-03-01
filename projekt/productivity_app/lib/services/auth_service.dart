import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerWithEmail(String email, String password, String nickname) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'nickname': nickname,
      'xp': 0,
      'coins': 0,
      'level': 1,
      'streak': 0,
      'lastActiveDate': null,
    });
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: kIsWeb
          ? '863209070202-ugd71j1mrv9nohbht9puakbr7991ccvv.apps.googleusercontent.com'
          : null,
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCred = await _auth.signInWithCredential(credential);

    await _firestore.collection('users').doc(userCred.user!.uid).set({
      'nickname': googleUser.displayName ?? 'Hrac',
      'photoUrl': googleUser.photoUrl,
    }, SetOptions(merge: true));

    final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
    final userData = userDoc.data();
    if (!userDoc.exists || userData == null || !userData.containsKey('xp')) {
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'xp': 0,
        'coins': 0,
        'level': 1,
        'streak': 0,
        'lastActiveDate': null,
      }, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Smazat úkoly
    final tasks = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .get();

    for (var doc in tasks.docs) {
      // Smazat i taskCodes záznam
      final taskData = doc.data();
      if (taskData['code'] != null) {
        await _firestore.collection('taskCodes').doc(taskData['code']).delete();
      }
      await doc.reference.delete();
    }

    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
  }
}
