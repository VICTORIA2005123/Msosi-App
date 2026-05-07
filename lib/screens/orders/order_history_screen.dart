import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/order_provider.dart';
import '../../widgets/payment_status_banner.dart';
import '../../models/order.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  void _showOrderQR(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pickup QR - #${order.id.substring(order.id.length - 5).toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Show this to the vendor to verify your pickup.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: order.id,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(order.id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
  }

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
                          final isReady = order.status.toLowerCase() == 'ready';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isReady ? Colors.green[100] : Colors.grey[200],
                                child: Icon(
                                  isReady ? Icons.check_circle : Icons.history,
                                  color: isReady ? Colors.green : Colors.grey,
                                ),
                              ),
                              title: Text('Order #${order.id.substring(order.id.length - 5).toUpperCase()}'),
                              subtitle: Text(
                                '${DateFormat('MMM dd, h:mm a').format(order.createdAt)}\nStatus: ${order.statusLabel}',
                                style: const TextStyle(height: 1.5),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${order.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (isReady) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.qr_code, color: Colors.deepOrange),
                                      onPressed: () => _showOrderQR(context, order),
                                      tooltip: 'Show Pickup QR',
                                    ),
                                  ],
                                ],
                              ),
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
