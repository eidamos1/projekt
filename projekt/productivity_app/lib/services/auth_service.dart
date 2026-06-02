import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/nickname_search.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Web OAuth client id for Google Sign-In (null on mobile/desktop where the
  // platform config is used). Single source of truth so sign-in and sign-out
  // operate on the same session.
  static const String _webGoogleClientId =
      '863209070202-ugd71j1mrv9nohbht9puakbr7991ccvv.apps.googleusercontent.com';

  GoogleSignIn _googleSignIn() =>
      GoogleSignIn(clientId: kIsWeb ? _webGoogleClientId : null);

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
      'nicknameLower': nicknameSearchKey(nickname),
      'xp': 0,
      'coins': 0,
      'level': 1,
      'streak': 0,
      'lastActiveDate': null,
    });
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = _googleSignIn();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCred = await _auth.signInWithCredential(credential);

    final userRef = _firestore.collection('users').doc(userCred.user!.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data();
    final isNewAccount =
        !userDoc.exists || userData == null || !userData.containsKey('xp');
    final existingNickname = (userData?['nickname'] as String?) ?? '';

    // photoUrl always tracks the Google avatar; nickname is only seeded on the
    // first sign-in (or if somehow blank). Re-writing it every login would
    // clobber a nickname the user later customised in-app — back to the Google
    // displayName — and reset their searchable nicknameLower with it.
    final updates = <String, dynamic>{'photoUrl': googleUser.photoUrl};
    if (isNewAccount || existingNickname.isEmpty) {
      final googleNickname = googleUser.displayName ?? 'Hráč';
      updates['nickname'] = googleNickname;
      updates['nicknameLower'] = nicknameSearchKey(googleNickname);
    }
    if (isNewAccount) {
      updates.addAll({
        'xp': 0,
        'coins': 0,
        'level': 1,
        'streak': 0,
        'lastActiveDate': null,
      });
    }
    await userRef.set(updates, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    // Clear the Google session as well. Without this the browser silently
    // re-authenticates the previously used Google account on the next
    // sign-in (no account chooser), so a user trying to switch accounts ends
    // up back on the first one — with its leftover nickname + photo.
    // Best-effort: a Google sign-out hiccup must not block the Firebase logout.
    try {
      await _googleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// True if the signed-in user authenticates with email/password — the caller
  /// must collect their password to re-authenticate before account deletion.
  bool get isPasswordUser =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  /// Re-authenticates the current user so a security-sensitive op (account
  /// deletion) won't fail with `requires-recent-login`. Google accounts go
  /// through the chooser; password accounts need [password]. Throws on failure
  /// (wrong password / cancelled popup) so the caller aborts BEFORE any
  /// destructive work — never leaving a half-deleted account.
  Future<void> _reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final providers = user.providerData.map((p) => p.providerId).toSet();

    if (providers.contains('google.com')) {
      final googleUser = await _googleSignIn().signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'reauth-cancelled',
          message: 'Google re-authentication was cancelled.',
        );
      }
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(cred);
    } else if (providers.contains('password')) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'reauth-missing-password',
          message: 'Password required to re-authenticate.',
        );
      }
      final cred =
          EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);
    }
  }

  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Re-authenticate FIRST. If this throws (wrong password / cancelled popup),
    // we abort before deleting anything — the account is never left half-erased.
    await _reauthenticate(password: password);

    // Snapshot friends + my tasks up front: needed to scrub the cross-user
    // notifs I authored (and reverse edges) before tearing my own data down.
    List<String> friendUids = const [];
    try {
      final friendsSnap =
          await _firestore.collection('users').doc(uid).collection('friends').get();
      friendUids = friendsSnap.docs.map((d) => d.id).toList();
    } catch (_) {}

    final tasks =
        await _firestore.collection('users').doc(uid).collection('tasks').get();
    final myTaskIds = tasks.docs.map((d) => d.id).toList();

    // Scrub the reverse friend edges + every notif I sent into friends' inboxes
    // (friend_added_{uid} and friend_pending_{taskId}). I'm the `fromUid` of
    // those notifs and a party to those edges, so the rules permit these.
    // Chunked to stay under the 500-op batch limit. Best-effort.
    WriteBatch batch = _firestore.batch();
    int ops = 0;
    Future<void> flush() async {
      if (ops == 0) return;
      try {
        await batch.commit();
      } catch (_) {}
      batch = _firestore.batch();
      ops = 0;
    }

    for (final fUid in friendUids) {
      final friendDoc = _firestore.collection('users').doc(fUid);
      batch.delete(friendDoc.collection('friends').doc(uid));
      batch.delete(friendDoc.collection('notifications').doc('friend_added_$uid'));
      ops += 2;
      for (final tId in myTaskIds) {
        batch.delete(
            friendDoc.collection('notifications').doc('friend_pending_$tId'));
        ops++;
        if (ops >= 400) await flush();
      }
      if (ops >= 400) await flush();
    }
    await flush();

    // Free up the invite code so it can be reused.
    try {
      final userSnap = await _firestore.collection('users').doc(uid).get();
      final myInviteCode = userSnap.data()?['inviteCode'] as String?;
      if (myInviteCode != null && myInviteCode.isNotEmpty) {
        await _firestore.collection('userInvites').doc(myInviteCode).delete();
      }
    } catch (_) {}

    // Delete tasks + their global taskCodes index entries.
    for (final doc in tasks.docs) {
      final code = doc.data()['code'];
      if (code != null) {
        try {
          await _firestore.collection('taskCodes').doc(code).delete();
        } catch (_) {}
      }
      await doc.reference.delete();
    }

    // Firestore does NOT cascade-delete subcollections — drop each explicitly,
    // otherwise they orphan forever once this uid can never authenticate again.
    for (final sub in const [
      'habits',
      'achievements',
      'notifications',
      'weeklyWinners',
      'friends',
    ]) {
      await _deleteSubcollection(uid, sub);
    }

    await _firestore.collection('users').doc(uid).delete();
    await user.delete();

    // Drop the Google session too (same reason as signOut).
    try {
      await _googleSignIn().signOut();
    } catch (_) {}
  }

  Future<void> _deleteSubcollection(String uid, String name) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(name)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // best-effort
    }
  }
}
