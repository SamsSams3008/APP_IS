import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// Guarda las claves IronSource en Firestore (para que el cron del backend las use)
/// y opcionalmente en el dispositivo (secure storage).
class CredentialsRepository {
  CredentialsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.collectionUsers);

  Future<bool> hasCredentials() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    final email = data?[AppConstants.fieldIronsourceEmail] as String?;
    final secret = data?[AppConstants.fieldIronsourceSecret] as String?;
    return email != null && secret != null && email.isNotEmpty && secret.isNotEmpty;
  }

  /// Guarda en Firestore (para el cron) y en el dispositivo.
  Future<void> saveCredentials(String email, String secretKey) async {
    final uid = _auth.currentUser?.uid;
    await _secureStorage.write(
      key: AppConstants.storageIronsourceEmail,
      value: email.trim(),
    );
    await _secureStorage.write(
      key: AppConstants.storageIronsourceSecret,
      value: secretKey,
    );
    if (uid != null) {
      await _users.doc(uid).set({
        AppConstants.fieldIronsourceEmail: email.trim(),
        AppConstants.fieldIronsourceSecret: secretKey,
      }, SetOptions(merge: true));
    }
  }
}
