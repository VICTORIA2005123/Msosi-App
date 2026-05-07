import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/menu_item.dart';
import '../../providers/chat_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/firestore_service.dart';
import 'menu_item_form_screen.dart';

class VendorMenuScreen extends ConsumerWidget {
  const VendorMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(selectedVendorRestaurantProvider);
    final menuAsync = ref.watch(vendorMenuProvider);

    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menu Management')),
        body: const Center(child: Text('No restaurant selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${restaurant.name} Menu'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MenuItemFormScreen(restaurantId: restaurant.id),
            ),
          );
          if (result == true) {
            ref.invalidate(vendorMenuProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorMenuProvider),
        child: menuAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No menu items yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('Tap + to add your first item', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.available ? Colors.green[100] : Colors.red[100],
                      child: Icon(
                        item.available ? Icons.check : Icons.close,
                        color: item.available ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '₹${item.price.toStringAsFixed(2)} • ${item.prepTime} min prep',
                    ),
                    trailing: Transform.scale(
                      scale: 1.2, // Larger touch target
                      child: Switch(
                        value: item.available,
                        onChanged: (val) => _handleAction(context, ref, restaurant.id, item, 'toggle'),
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red[100],
                      ),
                    ),
                    onTap: () => _handleAction(context, ref, restaurant.id, item, 'edit'),
                    onLongPress: () => _handleAction(context, ref, restaurant.id, item, 'delete'),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String restaurantId, MenuItem item, String action) async {
    final service = ref.read(firestoreServiceProvider);

    switch (action) {
      case 'toggle':
        await service.toggleItemAvailability(restaurantId, item.id, !item.available);
        ref.invalidate(vendorMenuProvider);
        break;
      case 'edit':
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MenuItemFormScreen(restaurantId: restaurantId, existingItem: item),
          ),
        );
        if (result == true) ref.invalidate(vendorMenuProvider);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete "${item.itemName}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await service.deleteMenuItem(restaurantId, item.id);
          ref.invalidate(vendorMenuProvider);
        }
        break;
    }
  }
}
