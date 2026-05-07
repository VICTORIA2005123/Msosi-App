import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/app_user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();

  /// Sign in with email/password. Reads role from Firestore user doc.
  Future<AppUser?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fUser = credential.user;
      if (fUser != null) {
        final user = await _buildAppUser(fUser);
        await _cacheUser(user);
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

  /// Register a new user. Default role is student if not specified.
  Future<AppUser?> register(String name, String email, String password, {UserRole role = UserRole.student}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fUser = credential.user;
      if (fUser != null) {
        await fUser.updateDisplayName(name);
        final token = await fUser.getIdToken();

        final user = AppUser(
          id: fUser.uid,
          name: name,
          email: email,
          role: role,
          token: token,
        );

        // Create Firestore user document
        await _db.collection('users').doc(fUser.uid).set(user.toFirestore());

        await _cacheUser(user);
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

  /// Upgrade the current user's role to vendor via secure Cloud Function.
  Future<AppUser?> upgradeToVendor() async {
    final fUser = _auth.currentUser;
    if (fUser == null) return null;

    final token = await fUser.getIdToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/users/upgrade-to-vendor');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final user = await _buildAppUser(fUser);
      await _cacheUser(user);
      return user;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to upgrade to vendor');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _storage.deleteAll();
  }

  /// Reconstruct [AppUser] from Firebase Auth + Firestore doc.
  Future<AppUser?> getCurrentUser() async {
    final fUser = _auth.currentUser;
    if (fUser != null) {
      return await _buildAppUser(fUser);
    }

    // Fallback to cached user in secure storage
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      return AppUser.fromJson(json.decode(userStr));
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

  /// Build AppUser by reading role from Firestore.
  Future<AppUser> _buildAppUser(firebase_auth.User fUser) async {
    final token = await fUser.getIdToken();
    final doc = await _db.collection('users').doc(fUser.uid).get();

    if (doc.exists) {
      return AppUser.fromFirestore(doc, token: token);
    }

    // If doc doesn't exist yet (edge case), create it as student
    final user = AppUser(
      id: fUser.uid,
      name: fUser.displayName ?? fUser.email?.split('@')[0] ?? 'User',
      email: fUser.email ?? '',
      role: UserRole.student,
      token: token,
    );
    await _db.collection('users').doc(fUser.uid).set(user.toFirestore());
    return user;
  }

  Future<void> _cacheUser(AppUser user) async {
    await _storage.write(key: 'user', value: json.encode(user.toJson()));
  }
}
