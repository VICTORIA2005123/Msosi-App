import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/order_provider.dart';
import '../../widgets/payment_status_banner.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          const PaymentStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(orderHistoryProvider),
              child: ordersAsync.when(
                data: (orders) => orders.isEmpty
                    ? const Center(child: Text('No orders yet'))
                    : ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text('Order #${order.id}'),
                              subtitle: Text('${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}\nStatus: ${order.status}'),
                              trailing: Text('₹${order.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
