import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

final firestoreServiceProvider = Provider((ref) {
  return FirestoreService();
});

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

// Chat state management holding the conversation context
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  
  // Track context for numeric choices
  List<Restaurant>? _currentRestaurants;
  List<MenuItem>? _currentMenu;
  Restaurant? _selectedRestaurant;

  ChatNotifier(this.ref) : super([
    ChatMessage(
      text: "Hello! I'm Msosi. 👩🏾‍🍳\nPlease choose an option by typing its number:\n\n1. Show list of restaurants\n2. My orders\n3. Checkout cart\n4. Show cart",
      type: MessageType.bot,
    ),
  ]);

  void sendMessage(String text, {Restaurant? contextRestaurant}) async {
    state = [...state, ChatMessage(text: text, type: MessageType.user)];
    
    // Process input
    await _processCommand(text, contextRestaurant);
  }

  Future<void> _processCommand(String text, Restaurant? contextRestaurant) async {
    String cmd = text.trim().toLowerCase();
    
    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Handle Restaurant selection (via extra from navigation)
    if (contextRestaurant != null && cmd.startsWith('show me the menu for')) {
      _selectedRestaurant = contextRestaurant;
      await _showMenuForRestaurant(contextRestaurant);
      return;
    }

    // Handle numeric selection for restaurants
    if (_currentRestaurants != null && _currentMenu == null && int.tryParse(cmd) != null) {
      int idx = int.parse(cmd) - 1;
      if (idx >= 0 && idx < _currentRestaurants!.length) {
        _selectedRestaurant = _currentRestaurants![idx];
        await _showMenuForRestaurant(_selectedRestaurant!);
        return;
      }
    }

    // Handle numeric selection for menu items
    if (_currentMenu != null && int.tryParse(cmd) != null) {
      int idx = int.parse(cmd) - 1;
      if (idx >= 0 && idx < _currentMenu!.length) {
        final item = _currentMenu![idx];
        ref.read(cartProvider.notifier).addItem(item);
        _addBotResponse("✅ Added **${item.itemName}** to your cart!\nType another number to add more, or tap the giant Cart icon down below to checkout!");
        return;
      }
    }

    // Base commands
    if (cmd == '1' || cmd.contains('restaurant') || cmd.contains('list')) {
      await _fetchRestaurants();
    } else if (cmd == '2' || cmd == 'my orders' || cmd.contains('order')) {
      await _showMyOrders();
    } else if (cmd == '3' || cmd.contains('checkout') || cmd.contains('place order')) {
      await _checkoutFromChat();
    } else if (cmd == '4' || cmd == 'cart' || cmd.contains('show cart')) {
      _showCartSummary();
    } else {
      _addBotResponse(
        "I didn't quite catch that.\nTry:\n1 for restaurants\n2 for my orders\n3 to checkout cart\n4 to show cart",
      );
    }
  }

  Future<void> _fetchRestaurants() async {
    try {
      final restaurants = await ref.read(firestoreServiceProvider).getRestaurants();
      if (restaurants.isEmpty) {
        _addBotResponse("There are currently no restaurants available right now.");
        return;
      }
      _currentRestaurants = restaurants;
      _currentMenu = null; // Clear menu context

      String res = "Here is what's open right now. Type a number to see their menu:\n\n";
      for (int i = 0; i < restaurants.length; i++) {
        res += "${i + 1}. ${restaurants[i].name} (${restaurants[i].dietType})\n";
      }
      _addBotResponse(res);
    } catch (e) {
      _addBotResponse("Oops! I had trouble fetching the restaurants. Try again later.");
    }
  }

  Future<void> _showMenuForRestaurant(Restaurant r) async {
    try {
      final menu = await ref.read(firestoreServiceProvider).getMenu(r.id);
      if (menu.isEmpty) {
        _addBotResponse("Looks like ${r.name} has no items on the menu today!");
        return;
      }
      _currentMenu = menu;
      _currentRestaurants = null; // Clear restaurant context

      String res = "Here is the menu for **${r.name}**. Type a number to add an item to your cart! 🛒\n\n";
      for (int i = 0; i < menu.length; i++) {
        res += "${i + 1}. ${menu[i].itemName} - ₹${menu[i].price.toStringAsFixed(2)}\n";
      }
      _addBotResponse(res);
    } catch (e) {
      _addBotResponse("Error loading menu for ${r.name}.");
    }
  }

  Future<void> _showMyOrders() async {
    final user = ref.read(authProvider);
    if (user == null) {
      _addBotResponse("Please log in first to view your orders.");
      return;
    }

    try {
      final orders = await ref.read(firestoreServiceProvider).getOrders(user.id);
      if (orders.isEmpty) {
        _addBotResponse("You have no orders yet. Add items and type 3 to checkout.");
        return;
      }

      final buffer = StringBuffer("Here are your recent orders:\n\n");
      for (final order in orders.take(5)) {
        buffer.writeln(
          "• #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}"
          " | ${order.status} | ₹${order.totalPrice.toStringAsFixed(2)}",
        );
      }
      if (orders.length > 5) {
        buffer.writeln("\n...and ${orders.length - 5} more in the Orders tab.");
      }
      _addBotResponse(buffer.toString());
    } catch (e) {
      _addBotResponse("I couldn't fetch your orders right now. Please try again.");
    }
  }

  void _showCartSummary() {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      _addBotResponse("Your cart is empty. Pick a restaurant and type an item number to add food.");
      return;
    }

    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + (item.item.price * item.quantity),
    );
    final buffer = StringBuffer("Your cart:\n\n");
    for (final cart in cartItems) {
      buffer.writeln("• ${cart.item.itemName} x${cart.quantity} = ₹${(cart.item.price * cart.quantity).toStringAsFixed(2)}");
    }
    buffer.writeln("\nTotal: ₹${total.toStringAsFixed(2)}");
    buffer.writeln("Type 3 to place this order.");
    _addBotResponse(buffer.toString());
  }

  Future<void> _checkoutFromChat() async {
    final user = ref.read(authProvider);
    if (user == null) {
      _addBotResponse("Please log in first to place an order.");
      return;
    }

    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      _addBotResponse("Your cart is empty. Add menu items first.");
      return;
    }

    final restaurantId = cartItems.first.item.restaurantId;
    final itemsMap = cartItems
        .map(
          (ci) => {
            'menu_id': ci.item.id,
            'quantity': ci.quantity,
            'price': ci.item.price,
          },
        )
        .toList();
    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + (item.item.price * item.quantity),
    );

    try {
      final result = await ref.read(firestoreServiceProvider).placeOrder(
            user.id,
            restaurantId,
            total,
            itemsMap,
          );
      ref.read(cartProvider.notifier).clear();
      final orderId = (result['orderId'] ?? '').toString();
      _addBotResponse(
        "Order placed successfully! 🎉\nOrder ID: $orderId\nType 2 any time to view your latest orders.",
      );
    } catch (e) {
      _addBotResponse("Checkout failed. Please try again or use the cart checkout button.");
    }
  }

  void _addBotResponse(String text) {
    state = [...state, ChatMessage(text: text, type: MessageType.bot)];
  }
}

