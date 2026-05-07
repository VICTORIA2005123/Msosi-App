import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles available in the Msosi system.
enum UserRole { student, vendor, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? token;
  final String? fcmToken;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.student,
    this.token,
    this.fcmToken,
  });

  bool get isVendor => role == UserRole.vendor;
  bool get isStudent => role == UserRole.student;
  bool get isAdmin => role == UserRole.admin;

  /// Create from Firestore document + optional auth token.
  factory AppUser.fromFirestore(DocumentSnapshot doc, {String? token}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: _parseRole(data['role']),
      token: token,
      fcmToken: data['fcm_token'],
    );
  }

  /// Create from a plain JSON map (e.g. secure storage cache).
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role']),
      token: json['token'],
      fcmToken: json['fcm_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'token': token,
      'fcm_token': fcmToken,
    };
  }

  /// Data written to the Firestore `users/{uid}` document.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      if (fcmToken != null) 'fcm_token': fcmToken,
    };
  }

  static UserRole _parseRole(dynamic value) {
    if (value is String) {
      return UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.student,
      );
    }
    return UserRole.student;
  }
}
