import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart';

final restaurantListProvider = FutureProvider<List<Restaurant>>((ref) async {
  return ref.watch(firestoreServiceProvider).getRestaurants();
});

final menuProvider = FutureProvider.family<List<MenuItem>, String>((ref, restaurantId) async {
  return ref.watch(firestoreServiceProvider).getMenu(restaurantId);
});

final restaurantSearchProvider = StateProvider<String>((ref) => "");

final filteredRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final restaurants = ref.watch(restaurantListProvider);
  final search = ref.watch(restaurantSearchProvider).toLowerCase();

  return restaurants.whenData((list) {
    if (search.isEmpty) return list;
    
    // In a real app, you'd fetch all menu items or use a search index.
    // Here we'll search by vendor name and mock search by location/tags.
    return list.where((r) {
      final nameMatch = r.name.toLowerCase().contains(search);
      final locationMatch = r.location.toLowerCase().contains(search);
      // Mocking menu item search by checking if search matches any likely keywords
      final mockMenuMatch = search.length > 3 && ['pizza', 'burger', 'coffee', 'pasta', 'rice', 'chicken'].any((k) => k.contains(search));
      
      return nameMatch || locationMatch || mockMenuMatch;
    }).toList();
  });
});
