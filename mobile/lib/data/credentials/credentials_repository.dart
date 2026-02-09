import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

class IronSourceCredentials {
  const IronSourceCredentials({
    required this.email,
    required this.secretKey,
  });

  final String email;
  final String secretKey;

  String get basicAuthHeader {
    final credentials = '$email:$secretKey';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }
}

/// Stores and retrieves IronSource API credentials.
/// Tries Firestore first (synced per user), then local secure storage.
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

  Future<IronSourceCredentials?> getCredentials() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _getFromSecureStorage();

    try {
      final doc = await _users.doc(uid).get();
      final data = doc.data();
      if (data != null) {
        final email = data[AppConstants.fieldIronsourceEmail] as String?;
        final secret = data[AppConstants.fieldIronsourceSecret] as String?;
        if (email != null && secret != null && email.isNotEmpty && secret.isNotEmpty) {
          return IronSourceCredentials(email: email, secretKey: secret);
        }
      }
    } catch (_) {}
    return _getFromSecureStorage();
  }

  Future<IronSourceCredentials?> _getFromSecureStorage() async {
    final email = await _secureStorage.read(key: AppConstants.storageIronsourceEmail);
    final secret = await _secureStorage.read(key: AppConstants.storageIronsourceSecret);
    if (email != null && secret != null && email.isNotEmpty && secret.isNotEmpty) {
      return IronSourceCredentials(email: email, secretKey: secret);
    }
    return null;
  }

  Future<void> saveCredentials(String email, String secretKey) async {
    final uid = _auth.currentUser?.uid;
    await _secureStorage.write(key: AppConstants.storageIronsourceEmail, value: email);
    await _secureStorage.write(key: AppConstants.storageIronsourceSecret, value: secretKey);
    if (uid != null) {
      await _users.doc(uid).set({
        AppConstants.fieldIronsourceEmail: email.trim(),
        AppConstants.fieldIronsourceSecret: secretKey,
      }, SetOptions(merge: true));
    }
  }

  Future<bool> hasCredentials() async {
    final c = await getCredentials();
    return c != null;
  }
}
