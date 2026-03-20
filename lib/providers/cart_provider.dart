import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(MenuItem item) {
    final index = state.indexWhere((element) => element.item.id == item.id);
    if (index != -1) {
      state[index].quantity++;
      state = [...state];
    } else {
      state = [...state, CartItem(item: item)];
    }
  }

  void removeItem(MenuItem item) {
    state = state.where((element) => element.item.id != item.id).toList();
  }

  void updateQuantity(MenuItem item, int quantity) {
    final index = state.indexWhere((element) => element.item.id == item.id);
    if (index != -1) {
      if (quantity <= 0) {
        removeItem(item);
      } else {
        state[index].quantity = quantity;
        state = [...state];
      }
    }
  }

  double get totalPrice {
    return state.fold(0, (sum, item) => sum + (item.item.price * item.quantity));
  }

  void clear() {
    state = [];
  }
}
