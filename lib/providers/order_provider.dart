import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import 'auth_provider.dart';
import '../services/firestore_service.dart';
import 'chat_provider.dart';

final orderHistoryProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref.watch(firestoreServiceProvider).getOrders(user.id);
});

final activeOrderStreamProvider = StreamProvider<Order?>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value(null);
  
  return ref.watch(firestoreServiceProvider).streamUserOrders(user.id).map((orders) {
    if (orders.isEmpty) return null;
    // Return the most recent non-completed order
    final active = orders.where((o) => o.status != 'completed' && o.status != 'cancelled').toList();
    return active.isNotEmpty ? active.first : null;
  });
});
