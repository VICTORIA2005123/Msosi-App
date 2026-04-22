import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/payment_controller.dart';

/// Persistent feedback banner for the latest payment result/error.
class PaymentStatusBanner extends ConsumerWidget {
  const PaymentStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentCheckoutControllerProvider);
    final notifier = ref.read(paymentCheckoutControllerProvider.notifier);

    final hasError = state.errorMessage != null && state.errorMessage!.isNotEmpty;
    final hasSuccess = state.lastResult != null;
    if (!hasError && !hasSuccess) {
      return const SizedBox.shrink();
    }

    final isError = hasError;
    final message = isError
        ? state.errorMessage!
        : 'Payment ${state.lastResult!.status}. Order #${state.lastResult!.orderId}';

    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : Colors.green.withValues(alpha: 0.14);
    final foreground = isError ? colorScheme.onErrorContainer : Colors.green[900];
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: notifier.clearTransientState,
                icon: Icon(Icons.close, color: foreground),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
