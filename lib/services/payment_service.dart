import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config/app_config.dart';
import '../models/payment_models.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

enum PaymentGateway { razorpay, stripe }

class PaymentFlowResult {
  const PaymentFlowResult({
    required this.orderId,
    required this.paymentId,
    required this.status,
  });

  final String orderId;
  final String paymentId;
  final String status;
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService(ref, http.Client());
  ref.onDispose(service.dispose);
  return service;
});

class PaymentService {
  PaymentService(this._ref, this._httpClient) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
  }

  final Ref _ref;
  final http.Client _httpClient;
  late final Razorpay _razorpay;

  Completer<PaymentSuccessResponse>? _razorpayCompleter;

  PaymentGateway get defaultGateway {
    return AppConfig.paymentGateway.toLowerCase() == 'stripe'
        ? PaymentGateway.stripe
        : PaymentGateway.razorpay;
  }

  Future<PaymentFlowResult> checkout({
    required PaymentGateway gateway,
    required User user,
    required String restaurantId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final createResponse = await _createBackendOrder(
      gateway: gateway,
      user: user,
      restaurantId: restaurantId,
      totalAmount: totalAmount,
      items: items,
    );

    if (gateway == PaymentGateway.stripe) {
      await _runStripeSheet(createResponse);
      return _confirmBackendPayment(
        gateway: gateway,
        appOrderId: createResponse.appOrderId,
        paymentPayload: {
          'payment_intent_id': createResponse.paymentIntentId ?? '',
        },
      );
    }

    final razorpaySuccess = await _runRazorpayCheckout(
      createResponse: createResponse,
      user: user,
      totalAmount: totalAmount,
    );

    return _confirmBackendPayment(
      gateway: gateway,
      appOrderId: createResponse.appOrderId,
      paymentPayload: {
        'razorpay_payment_id': razorpaySuccess.paymentId ?? '',
        'razorpay_order_id': razorpaySuccess.orderId ?? '',
        'razorpay_signature': razorpaySuccess.signature ?? '',
      },
    );
  }

  Future<CreatePaymentOrderResponse> _createBackendOrder({
    required PaymentGateway gateway,
    required User user,
    required String restaurantId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final token = await _ref.read(authServiceProvider).getToken();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/create-order');
    final request = CreatePaymentOrderRequest(
      gateway: gateway.name,
      userId: user.id,
      restaurantId: restaurantId,
      totalAmount: totalAmount,
      currency: 'INR',
      items: items,
    );
    final response = await _httpClient.post(
      url,
      headers: _headers(token),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create payment order: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid create-order response.');
    }
    final parsed = CreatePaymentOrderResponse.fromJson(data);
    if (parsed.appOrderId.isEmpty) {
      throw Exception('Backend create-order response missing app_order_id.');
    }
    return parsed;
  }

  Future<void> _runStripeSheet(CreatePaymentOrderResponse createResponse) async {
    final clientSecret = createResponse.paymentIntentClientSecret ?? '';
    if (clientSecret.isEmpty) {
      throw Exception('Missing Stripe client secret from backend.');
    }
    if (AppConfig.stripePublishableKey.isEmpty) {
      throw Exception('Missing STRIPE_PUBLISHABLE_KEY dart-define.');
    }

    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Msosi',
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      throw Exception(e.error.localizedMessage ?? 'Stripe payment cancelled/failed.');
    }
  }

  Future<PaymentSuccessResponse> _runRazorpayCheckout({
    required CreatePaymentOrderResponse createResponse,
    required User user,
    required double totalAmount,
  }) async {
    final orderId = createResponse.razorpayOrderId ?? '';
    if (orderId.isEmpty) {
      throw Exception('Missing Razorpay order id from backend.');
    }

    final keyId = (createResponse.razorpayKeyId ?? '').isNotEmpty
        ? createResponse.razorpayKeyId!
        : AppConfig.razorpayKeyId;
    if (keyId.isEmpty) {
      throw Exception('Missing Razorpay key id (backend or RAZORPAY_KEY_ID).');
    }

    _razorpayCompleter = Completer<PaymentSuccessResponse>();
    _razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': (totalAmount * 100).round(),
      'currency': 'INR',
      'name': 'Msosi',
      'description': 'Campus food order',
      'prefill': {
        'email': user.email,
        'name': user.name,
      },
      'theme': {'color': '#FF5722'},
    });
    return _razorpayCompleter!.future;
  }

  Future<PaymentFlowResult> _confirmBackendPayment({
    required PaymentGateway gateway,
    required String appOrderId,
    required Map<String, dynamic> paymentPayload,
  }) async {
    final token = await _ref.read(authServiceProvider).getToken();
    final request = ConfirmPaymentRequest(
      gateway: gateway.name,
      appOrderId: appOrderId,
      paymentPayload: paymentPayload,
    );
    final response = await _httpClient.post(
      Uri.parse('${AppConfig.apiBaseUrl}/payments/confirm'),
      headers: _headers(token),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to confirm payment: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid confirm-payment response.');
    }

    final parsed = ConfirmPaymentResponse.fromJson(data);
    return PaymentFlowResult(
      orderId: parsed.orderId.isEmpty ? appOrderId : parsed.orderId,
      paymentId: parsed.paymentId,
      status: parsed.status,
    );
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    _razorpayCompleter?.complete(response);
    _razorpayCompleter = null;
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    _razorpayCompleter?.completeError(
      Exception(response.message ?? 'Razorpay payment failed.'),
    );
    _razorpayCompleter = null;
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    // Keep flow active; backend confirmation still happens after success callback.
  }

  void dispose() {
    _razorpay.clear();
    _httpClient.close();
  }
}
