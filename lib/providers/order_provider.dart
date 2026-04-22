import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';

final orderHistoryProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref.watch(firestoreServiceProvider).getOrders(user.id);
});
