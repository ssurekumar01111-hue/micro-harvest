import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthListenable extends ChangeNotifier {
  AuthListenable(FirebaseAuth auth) {
    auth.authStateChanges().listen((_) => notifyListeners());
  }
}
