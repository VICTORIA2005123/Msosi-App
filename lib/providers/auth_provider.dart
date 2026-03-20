import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<User?> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(null) {
    _init();
  }

  void _init() async {
    state = await _authService.getCurrentUser();
  }

  Future<String?> login(String email, String password) async {
    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        state = user;
        return null; // Return null on success
      }
      return 'Login failed. Please check your credentials.';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final user = await _authService.register(name, email, password);
      if (user != null) {
        return null; // Return null on success
      }
      return 'Registration failed. Please try again.';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }
}
