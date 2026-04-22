import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_controller.dart';
import '../../services/payment_service.dart';
import '../../widgets/payment_status_banner.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.read(cartProvider.notifier).totalPrice;
    final checkoutState = ref.watch(paymentCheckoutControllerProvider);

    Future<void> checkout(PaymentGateway gateway) async {
      if (checkoutState.isProcessing || cartItems.isEmpty) return;

      final user = ref.read(authProvider);
      if (user == null) {
        return;
      }

      final restaurantId = cartItems.first.item.restaurantId;
      final itemsMap = cartItems
          .map((ci) => {
                'menu_id': ci.item.id,
                'quantity': ci.quantity,
                'price': ci.item.price,
              })
          .toList();

      try {
        final paymentResult = await ref.read(paymentCheckoutControllerProvider.notifier).checkout(
              gateway: gateway,
              user: user,
              restaurantId: restaurantId,
              totalAmount: totalPrice,
              items: itemsMap,
            );
        ref.read(cartProvider.notifier).clear();
        ref.read(paymentCheckoutControllerProvider.notifier).clearTransientState();
        if (!context.mounted) return;
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment ${paymentResult.status}. Order #${paymentResult.orderId}',
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              checkoutState.errorMessage ?? 'Checkout failed: $e',
            ),
          ),
        );
      }
    }

    Future<void> openCheckout() async {
      final selectedGateway = await showModalBottomSheet<PaymentGateway>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final preferred = ref.read(paymentServiceProvider).defaultGateway;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: const Text('Razorpay'),
                  subtitle: const Text('UPI, cards, wallets, netbanking'),
                  trailing:
                      preferred == PaymentGateway.razorpay ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () => Navigator.of(context).pop(PaymentGateway.razorpay),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Stripe'),
                  subtitle: const Text('Card payment sheet'),
                  trailing: preferred == PaymentGateway.stripe ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () => Navigator.of(context).pop(PaymentGateway.stripe),
                ),
              ],
            ),
          );
        },
      );
      if (selectedGateway == null) return;
      await checkout(selectedGateway);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: Column(
        children: [
          const PaymentStatusBanner(),
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text('Your cart is empty'))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final ci = cartItems[index];
                            return ListTile(
                              title: Text(ci.item.itemName),
                              subtitle: Text('₹${ci.item.price.toStringAsFixed(2)} x ${ci.quantity}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => ref.read(cartProvider.notifier).updateQuantity(ci.item, ci.quantity - 1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => ref.read(cartProvider.notifier).updateQuantity(ci.item, ci.quantity + 1),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('₹${totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: checkoutState.isProcessing ? null : openCheckout,
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                              child: checkoutState.isProcessing
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Checkout'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
