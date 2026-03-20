import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/restaurant.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/cart_provider.dart';

class MenuScreen extends ConsumerWidget {
  final Restaurant restaurant;

  const MenuScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider(restaurant.id));

    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: menuAsync.when(
        data: (menu) => ListView.builder(
          itemCount: menu.length,
          itemBuilder: (context, index) {
            final item = menu[index];
            return ListTile(
              title: Text(item.itemName),
              subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
              trailing: item.available
                  ? ElevatedButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.itemName} added to cart')),
                        );
                      },
                      child: const Text('Add'),
                    )
                  : const Text('Out of Stock', style: TextStyle(color: Colors.red)),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
