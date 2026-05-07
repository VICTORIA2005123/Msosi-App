import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart';

/// Provider for the vendor's own restaurants.
final vendorRestaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return ref.watch(firestoreServiceProvider).getVendorRestaurants(user.id);
});

/// Currently selected restaurant for vendor management.
final selectedVendorRestaurantProvider = StateProvider<Restaurant?>((ref) => null);

/// Menu items for the selected vendor restaurant.
final vendorMenuProvider = FutureProvider<List<MenuItem>>((ref) async {
  final restaurant = ref.watch(selectedVendorRestaurantProvider);
  if (restaurant == null) return [];
  return ref.watch(firestoreServiceProvider).getMenu(restaurant.id);
});

/// Real-time stream of orders for the selected vendor restaurant.
final vendorOrdersStreamProvider = StreamProvider<List<Order>>((ref) {
  final restaurant = ref.watch(selectedVendorRestaurantProvider);
  if (restaurant == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).streamVendorOrders(restaurant.id);
});
