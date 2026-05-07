import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_controller.dart';
import '../../services/firestore_service.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/time_slot_picker.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  DateTime? _selectedPickupTime;
  bool _isPlacingOrder = false;

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.read(cartProvider.notifier).totalPrice;

    // Calculate max prep time across all cart items
    final maxPrepTime = cartItems.isEmpty
        ? 0
        : cartItems.map((ci) => ci.item.prepTime).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: cartItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your cart is empty', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            )
          : Column(
              children: [
                // Cart items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length + 1, // +1 for time slot picker
                    itemBuilder: (context, index) {
                      if (index < cartItems.length) {
                        final ci = cartItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(ci.item.itemName),
                            subtitle: Text(
                              '₹${ci.item.price.toStringAsFixed(2)} × ${ci.quantity} • ${ci.item.prepTime} min',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
                                  onPressed: () => ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(ci.item, ci.quantity - 1),
                                ),
                                Text('${ci.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
                                  onPressed: () => ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(ci.item, ci.quantity + 1),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Time slot picker at the end
                      return TimeSlotPicker(
                        maxPrepTimeMinutes: maxPrepTime,
                        selectedSlot: _selectedPickupTime,
                        onSlotSelected: (slot) {
                          setState(() => _selectedPickupTime = slot);
                        },
                      );
                    },
                  ),
                ),

                // Bottom checkout bar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPickupTime != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Pickup: ${TimeOfDay.fromDateTime(_selectedPickupTime!).format(context)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: (_selectedPickupTime == null || _isPlacingOrder)
                            ? null
                            : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: _isPlacingOrder
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _selectedPickupTime == null
                                    ? 'Select a Pickup Time'
                                    : 'Place Order',
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _placeOrder() async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    setState(() => _isPlacingOrder = true);

    try {
      final restaurantId = cartItems.first.item.restaurantId;
      final itemsMap = cartItems
          .map((ci) => {
                'menu_id': ci.item.id,
                'item_name': ci.item.itemName,
                'quantity': ci.quantity,
                'price': ci.item.price,
              })
          .toList();
      final total = cartItems.fold<double>(
        0,
        (sum, item) => sum + (item.item.price * item.quantity),
      );

      final result = await ref.read(firestoreServiceProvider).placeOrder(
        user.id,
        restaurantId,
        total,
        itemsMap,
        pickupTime: _selectedPickupTime,
      );

      ref.read(cartProvider.notifier).clear();
      final orderId = (result['orderId'] ?? '').toString();

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed! 🎉 #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}
