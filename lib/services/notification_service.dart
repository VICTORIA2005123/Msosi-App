import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  NotificationService(this.ref);

  /// Request permissions and initialize FCM
  Future<void> initialize() async {
    // Only initialize on supported platforms
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted permission for notifications');
          
          // Listen to token refresh
          FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
          
          // Initial token save if user is already logged in
          final user = ref.read(authProvider);
          if (user != null) {
            await saveToken();
          }

          // Handle foreground messages
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            debugPrint('Got a message whilst in the foreground!');
            debugPrint('Message data: ${message.data}');

            if (message.notification != null) {
              debugPrint('Message also contained a notification: ${message.notification}');
              // Could show a local snackbar here using an injected navigator key,
              // but for now relying on system tray if background, and console if foreground.
            }
          });
        }
      } catch (e) {
        debugPrint('Error initializing FCM: $e');
      }
    }
  }

  /// Get FCM token and save to user's document
  Future<void> saveToken() async {
    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.id).update({
        'fcm_token': token,
        'token_updated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token saved for user ${user.id}');
    } catch (e) {
      // If document doesn't exist or isn't completely initialized yet, fail gracefully
      debugPrint('Error writing token to Firestore: $e');
    }
  }

  /// Remove FCM token on logout
  Future<void> removeToken() async {
    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      await _db.collection('users').doc(user.id).update({
        'fcm_token': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error removing token: $e');
    }
  }
}

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
