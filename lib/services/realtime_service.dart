import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config/app_config.dart';
import '../providers/order_provider.dart';

/// Connects to the campus backend WebSocket and refreshes local state when
/// orders or vendor queues change. Your server should emit JSON such as:
/// `{ "type": "order_updated" }` or `{ "type": "new_order" }`.
class RealtimeService {
  RealtimeService(this._ref);

  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  bool get isEnabled => AppConfig.wsUrl.isNotEmpty;

  Future<void> connect(String token) async {
    if (!isEnabled) return;
    await disconnect();

    final base = Uri.parse(AppConfig.wsUrl);
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        'token': token,
      },
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );
    } catch (_) {
      _channel = null;
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic>? map;
    try {
      map = json.decode(data) as Map<String, dynamic>?;
    } catch (_) {
      return;
    }
    if (map == null) return;

    final type = map['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'order_updated':
      case 'new_order':
      case 'order_status':
      case 'menu_updated':
        _ref.invalidate(orderHistoryProvider);
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(ref);
});
