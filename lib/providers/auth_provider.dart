import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref, ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AppUser?> {
  final Ref ref;
  final AuthService _authService;

  AuthNotifier(this.ref, this._authService) : super(null) {
    _init();
  }

  void _init() async {
    state = await _authService.getCurrentUser();

    // Listen to Firebase Auth state changes
    firebase_auth.FirebaseAuth.instance.authStateChanges().listen((fUser) async {
      // Don't overwrite if we are in manual audit mode
      if (state?.id == 'audit-user') return;
      
      if (fUser == null) {
        state = null;
      } else {
        state = await _authService.getCurrentUser();
        // Initialize notifications after auth is restored
        ref.read(notificationServiceProvider).initialize();
      }
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        state = user;
        await ref.read(notificationServiceProvider).initialize();
        return null; // Return null on success
      }
      return 'Login failed. Please check your credentials.';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Register a new user account.
  Future<String?> register(String name, String email, String password, {UserRole role = UserRole.student}) async {
    try {
      final user = await _authService.register(name, email, password, role: role);
      if (user != null) {
        state = user;
        await ref.read(notificationServiceProvider).initialize();
        return null; // Return null on success
      }
      return 'Registration failed. Please try again.';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Upgrade the current user to vendor role.
  Future<String?> upgradeToVendor() async {
    try {
      final user = await _authService.upgradeToVendor();
      if (user != null) {
        state = user;
        return null;
      }
      return 'Failed to upgrade to vendor.';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> logout() async {
    await ref.read(notificationServiceProvider).removeToken();
    await _authService.logout();
    state = null;
  }
}
