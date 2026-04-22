import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/realtime_service.dart';

/// Keeps the WebSocket connected whenever a user is logged in (if [AppConfig.wsUrl] is set).
class RealtimeConnection extends ConsumerWidget {
  const RealtimeConnection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<User?>(authProvider, (previous, next) async {
      final rt = ref.read(realtimeServiceProvider);
      if (next == null) {
        await rt.disconnect();
        return;
      }
      final token = await ref.read(authServiceProvider).getToken();
      if (token != null && token.isNotEmpty) {
        await rt.connect(token);
      }
    });

    return child;
  }
}
