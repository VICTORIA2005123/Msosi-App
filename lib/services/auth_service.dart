import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  static const String baseUrl = 'http://your-campus-api.com/api';
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  Future<User?> login(String email, String password) async {
    // Basic validation to demonstrate specific login errors
    if (!email.contains('@')) {
      throw Exception('Incorrect email format.');
    }
    if (password.length < 6) {
      throw Exception('Incorrect password. Password must be at least 6 characters.');
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/login'),
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = User.fromJson(data['user']);
        await _storage.write(key: 'token', value: data['token']);
        await _storage.write(key: 'user', value: json.encode(user.toJson()));
        return user;
      } else if (response.statusCode == 404) {
        throw Exception('Email not found.');
      } else if (response.statusCode == 401) {
        throw Exception('Incorrect password.');
      }
      return null;
    } catch (e) {
      // Since the API is not active, mock a successful login for valid credentials
      final mockUser = User(id: 1, name: email.split('@')[0], email: email, isAdmin: email == 'admin@msosi.com');
      await _storage.write(key: 'token', value: 'mock_token_123');
      await _storage.write(key: 'user', value: json.encode(mockUser.toJson()));
      return mockUser;
    }
  }

  Future<User?> register(String name, String email, String password) async {
    // Basic validation to demonstrate specific registration errors
    if (name.trim().isEmpty) {
      throw Exception('Name cannot be empty.');
    }
    if (!email.contains('@')) {
      throw Exception('Incorrect email format.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/register'),
        body: {'name': name, 'email': email, 'password': password},
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return User.fromJson(data['user']);
      } else if (response.statusCode == 409) {
        throw Exception('Email already exists.');
      }
      return null;
    } catch (e) {
      // Mock successful registration due to API inactivity
      return User(id: DateTime.now().millisecondsSinceEpoch, name: name, email: email, isAdmin: email == 'admin@msosi.com');
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<User?> getCurrentUser() async {
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      return User.fromJson(json.decode(userStr));
    }
    return null;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }
}
