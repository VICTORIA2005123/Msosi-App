import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import 'chat_provider.dart';

final restaurantListProvider = FutureProvider<List<Restaurant>>((ref) async {
  return ref.watch(apiServiceProvider).getRestaurants();
});

final menuProvider = FutureProvider.family<List<MenuItem>, int>((ref, restaurantId) async {
  return ref.watch(apiServiceProvider).getMenu(restaurantId);
});

final restaurantSearchProvider = StateProvider<String>((ref) => "");

final filteredRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final restaurants = ref.watch(restaurantListProvider);
  final search = ref.watch(restaurantSearchProvider).toLowerCase();

  return restaurants.whenData((list) {
    if (search.isEmpty) return list;
    return list.where((r) => r.name.toLowerCase().contains(search) || r.location.toLowerCase().contains(search)).toList();
  });
});
