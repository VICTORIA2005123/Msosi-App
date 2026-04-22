import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/payment_service.dart';

class PaymentCheckoutState {
  const PaymentCheckoutState({
    this.isProcessing = false,
    this.errorMessage,
    this.lastResult,
  });

  final bool isProcessing;
  final String? errorMessage;
  final PaymentFlowResult? lastResult;

  PaymentCheckoutState copyWith({
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
    PaymentFlowResult? lastResult,
    bool clearResult = false,
  }) {
    return PaymentCheckoutState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    );
  }
}

class PaymentCheckoutController extends StateNotifier<PaymentCheckoutState> {
  PaymentCheckoutController(this._ref) : super(const PaymentCheckoutState());

  final Ref _ref;

  Future<PaymentFlowResult> checkout({
    required PaymentGateway gateway,
    required User user,
    required String restaurantId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    if (state.isProcessing) {
      throw Exception('A payment is already in progress.');
    }
    state = state.copyWith(isProcessing: true, clearError: true, clearResult: true);
    try {
      final result = await _ref.read(paymentServiceProvider).checkout(
            gateway: gateway,
            user: user,
            restaurantId: restaurantId,
            totalAmount: totalAmount,
            items: items,
          );
      state = state.copyWith(isProcessing: false, lastResult: result, clearError: true);
      return result;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  void clearTransientState() {
    state = state.copyWith(clearError: true, clearResult: true);
  }
}

final paymentCheckoutControllerProvider =
    StateNotifierProvider<PaymentCheckoutController, PaymentCheckoutState>((ref) {
  return PaymentCheckoutController(ref);
});
