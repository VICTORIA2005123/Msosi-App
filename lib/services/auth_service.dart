import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();

  Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final fUser = credential.user;
      if (fUser != null) {
        final token = await fUser.getIdToken();
        final user = User(
          id: fUser.uid,
          name: fUser.displayName ?? email.split('@')[0],
          email: fUser.email ?? email,
          token: token,
          isAdmin: email == 'admin@msosi.com',
        );
        await _storage.write(key: 'user', value: json.encode(user.toJson()));
        return user;
      }
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Email not found.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Incorrect email format.');
      }
      throw Exception(e.message ?? 'Authentication failed');
    }
  }

  Future<User?> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final fUser = credential.user;
      if (fUser != null) {
        await fUser.updateDisplayName(name);
        final token = await fUser.getIdToken();
        final user = User(
          id: fUser.uid,
          name: name,
          email: email,
          token: token,
          isAdmin: email == 'admin@msosi.com',
        );
        await _storage.write(key: 'user', value: json.encode(user.toJson()));
        return user;
      }
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email already exists.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password must be at least 6 characters.');
      }
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _storage.deleteAll();
  }

  Future<User?> getCurrentUser() async {
    final fUser = _auth.currentUser;
    if (fUser != null) {
      final token = await fUser.getIdToken();
      return User(
        id: fUser.uid,
        name: fUser.displayName ?? fUser.email?.split('@')[0] ?? 'User',
        email: fUser.email ?? '',
        token: token,
        isAdmin: fUser.email == 'admin@msosi.com',
      );
    }
    
    // Fallback to storage if not natively logged in via Firebase Auth yet
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      return User.fromJson(json.decode(userStr));
    }
    return null;
  }

  Future<String?> getToken() async {
    final fUser = _auth.currentUser;
    if (fUser != null) {
      return await fUser.getIdToken();
    }
    return null;
  }
}
