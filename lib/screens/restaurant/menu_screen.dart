import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/restaurant.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/cart_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key, required this.restaurantId, this.restaurant});

  final String restaurantId;
  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider(restaurantId));
    final cartItems = ref.watch(cartProvider);
    final cartCount = cartItems.fold<int>(0, (sum, ci) => sum + ci.quantity);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          restaurant?.name ?? 'Menu',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
      ),
      floatingActionButton: cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/cart'),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text('View Cart ($cartCount)'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
            )
          : null,
      body: menuAsync.when(
        data: (items) {
          final available = items.where((i) => i.available).toList();
          if (available.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_food_rounded, size: 80, color: Colors.grey),
                  SizedBox(height: 24),
                  Text(
                    'No items available',
                    style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: available.length,
            itemBuilder: (context, index) {
              final item = available[index];
              final inCart = cartItems.indexWhere((ci) => ci.item.id == item.id);
              final quantity = inCart != -1 ? cartItems[inCart].quantity : 0;

              return _MenuItemCard(
                item: item,
                quantity: quantity,
                onAdd: () {
                  if (cartItems.isNotEmpty && cartItems.first.item.restaurantId != restaurantId) {
                    _showClearCartDialog(context, ref, item);
                    return;
                  }
                  _showItemCustomization(context, ref, item);
                },
                onUpdate: (q) {
                   if (q == 0) {
                     ref.read(cartProvider.notifier).removeItem(item);
                   } else {
                     ref.read(cartProvider.notifier).updateQuantity(item, q);
                   }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showItemCustomization(BuildContext context, WidgetRef ref, dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemCustomizationSheet(item: item),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Different Restaurant'),
        content: const Text(
          'Your cart has items from another restaurant. '
          'Would you like to clear your cart and add this item?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              ref.read(cartProvider.notifier).addItem(item);
              Navigator.pop(ctx);
            },
            child: const Text('Clear & Add', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final dynamic item;
  final int quantity;
  final VoidCallback onAdd;
  final Function(int) onUpdate;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.02),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04)),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        '${item.prepTime} min',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (quantity == 0)
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                      onPressed: () => onUpdate(quantity - 1),
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      onPressed: () => onUpdate(quantity + 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemCustomizationSheet extends ConsumerWidget {
  final dynamic item;

  const _ItemCustomizationSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.8),
                    ),
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[100],
                  child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'CUSTOMIZE YOUR MEAL',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _CustomOption(label: 'Extra Spicy', price: 0),
          _CustomOption(label: 'Add Extra Sauce', price: 10),
          _CustomOption(label: 'Large Portion', price: 40),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).addItem(item);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${item.itemName} to cart'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56), // > 48px touch target
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('ADD TO CART', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _CustomOption extends StatefulWidget {
  final String label;
  final int price;

  const _CustomOption({required this.label, required this.price});

  @override
  State<_CustomOption> createState() => _CustomOptionState();
}

class _CustomOptionState extends State<_CustomOption> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => selected = !selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(4),
                color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              ),
              child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
            const SizedBox(width: 16),
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black)),
            const Spacer(),
            if (widget.price > 0)
              Text('+₹${widget.price}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
