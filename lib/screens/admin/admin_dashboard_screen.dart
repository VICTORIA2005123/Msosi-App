import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/restaurant.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/firestore_service.dart';
import '../vendor/vendor_menu_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final restaurantsAsync = ref.watch(vendorRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: restaurantsAsync.when(
        data: (restaurants) {
          if (restaurants.isEmpty) {
            return _buildNoRestaurant(context, user?.id ?? '');
          }

          // Auto-select first restaurant if none selected
          final selected = ref.watch(selectedVendorRestaurantProvider);
          if (selected == null && restaurants.isNotEmpty) {
            Future.microtask(() {
              ref.read(selectedVendorRestaurantProvider.notifier).state = restaurants.first;
            });
            return const Center(child: CircularProgressIndicator());
          }

          return _buildDashboard(context, ref, selected!, restaurants);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildNoRestaurant(BuildContext context, String vendorId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No restaurants yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createRestaurant(context, vendorId),
              icon: const Icon(Icons.add),
              label: const Text('Create Restaurant'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, Restaurant restaurant, List<Restaurant> allRestaurants) {
    final ordersAsync = ref.watch(vendorOrdersStreamProvider);
    bool isBusy = restaurant.openingHours.contains('BUSY'); // Mocking busy state via hours for now or use a metadata field

    return Column(
      children: [
        // Restaurant header + Busy Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    Text(restaurant.location, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('KITCHEN HEAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Standard', label: Text('Normal', style: TextStyle(fontSize: 10))),
                      ButtonSegment(value: 'Busy', label: Text('Busy', style: TextStyle(fontSize: 10))),
                      ButtonSegment(value: 'Slammed', label: Text('Slammed', style: TextStyle(fontSize: 10))),
                    ],
                    selected: {restaurant.kitchenHeat},
                    onSelectionChanged: (newSelection) async {
                      final heat = newSelection.first;
                      await ref.read(firestoreServiceProvider).updateRestaurant(
                        restaurant.id,
                        {'kitchen_heat': heat},
                      );
                      ref.invalidate(vendorRestaurantsProvider);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: Colors.red,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Switch(
                    value: restaurant.isOpen,
                    onChanged: (open) async {
                      await ref.read(firestoreServiceProvider).updateRestaurant(
                        restaurant.id,
                        {'is_open': open},
                      );
                      ref.invalidate(vendorRestaurantsProvider);
                    },
                    activeColor: Colors.green,
                  ),
                  Text(
                    restaurant.isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: restaurant.isOpen ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Order Feed Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'LIVE ORDER FEED',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const Spacer(),
              _UrgencyLegend(),
            ],
          ),
        ),

        // Orders list
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Waiting for new orders...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final ageInMinutes = DateTime.now().difference(order.createdAt).inMinutes;
                  
                  Color urgencyColor = Colors.green;
                  if (ageInMinutes >= 20) {
                    urgencyColor = Colors.red;
                  } else if (ageInMinutes >= 10) {
                    urgencyColor = Colors.orange;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shadowColor: urgencyColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: urgencyColor, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ORDER #${order.id.substring(order.id.length - 5).toUpperCase()}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                  ),
                                  Text(
                                    '${ageInMinutes}m ago',
                                    style: TextStyle(color: urgencyColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              _statusChip(order.status),
                            ],
                          ),
                          const Divider(height: 32),
                          ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                  child: Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.itemName ?? 'Item',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 20),
                          _buildStatusActions(context, ref, order.id, order.status),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'preparing':
        color = Colors.blue;
        icon = Icons.restaurant;
        break;
      case 'ready':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatusActions(BuildContext context, WidgetRef ref, String orderId, String currentStatus) {
    final status = currentStatus.toLowerCase();
    String? nextStatus;
    String? label;
    Color? color;

    switch (status) {
      case 'pending':
        nextStatus = 'preparing';
        label = 'START PREPARING';
        color = Colors.blue;
        break;
      case 'preparing':
        nextStatus = 'ready';
        label = 'MARK READY';
        color = Colors.green;
        break;
      case 'ready':
        nextStatus = 'completed';
        label = 'COMPLETE ORDER';
        color = Colors.grey[700];
        break;
      default:
        return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (status == 'pending' || status == 'preparing')
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              onPressed: () => _showCancelDialog(context, ref, orderId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(60, 60), // Large touch target
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Icon(Icons.close),
            ),
          ),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(firestoreServiceProvider).updateOrderStatus(orderId, nextStatus!);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60), // Large touch target
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone and the student will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KEEP ORDER')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).updateOrderStatus(orderId, 'cancelled');
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  void _createRestaurant(BuildContext context, String vendorId) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final hoursController = TextEditingController(text: '08:00 - 20:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Restaurant Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(labelText: 'Opening Hours', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final restaurant = Restaurant(
                id: '',
                vendorId: vendorId,
                name: nameController.text.trim(),
                location: locationController.text.trim(),
                openingHours: hoursController.text.trim(),
              );
              await ref.read(firestoreServiceProvider).createRestaurant(restaurant);
              ref.invalidate(vendorRestaurantsProvider);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _UrgencyLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(Colors.green),
        const SizedBox(width: 4),
        const Text('New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        _dot(Colors.orange),
        const SizedBox(width: 4),
        const Text('10m+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        _dot(Colors.red),
        const SizedBox(width: 4),
        const Text('20m+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _dot(Color color) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
