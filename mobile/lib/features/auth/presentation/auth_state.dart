import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthState extends ChangeNotifier {
  AuthState({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  User? _user;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String? get email => _user?.email;

  Future<void> initialize() async {
    _user = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
