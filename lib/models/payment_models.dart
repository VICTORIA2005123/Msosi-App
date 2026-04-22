class CreatePaymentOrderRequest {
  const CreatePaymentOrderRequest({
    required this.gateway,
    required this.userId,
    required this.restaurantId,
    required this.totalAmount,
    required this.currency,
    required this.items,
  });

  final String gateway;
  final String userId;
  final String restaurantId;
  final double totalAmount;
  final String currency;
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> toJson() {
    return {
      'gateway': gateway,
      'user_id': userId,
      'restaurant_id': restaurantId,
      'total_amount': totalAmount,
      'currency': currency,
      'items': items,
    };
  }
}

class CreatePaymentOrderResponse {
  const CreatePaymentOrderResponse({
    required this.appOrderId,
    this.paymentIntentClientSecret,
    this.paymentIntentId,
    this.razorpayOrderId,
    this.razorpayKeyId,
  });

  final String appOrderId;
  final String? paymentIntentClientSecret;
  final String? paymentIntentId;
  final String? razorpayOrderId;
  final String? razorpayKeyId;

  factory CreatePaymentOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreatePaymentOrderResponse(
      appOrderId: json['app_order_id']?.toString() ?? '',
      paymentIntentClientSecret: json['payment_intent_client_secret']?.toString(),
      paymentIntentId: json['payment_intent_id']?.toString(),
      razorpayOrderId: json['razorpay_order_id']?.toString(),
      razorpayKeyId: json['razorpay_key_id']?.toString(),
    );
  }
}

class ConfirmPaymentRequest {
  const ConfirmPaymentRequest({
    required this.gateway,
    required this.appOrderId,
    required this.paymentPayload,
  });

  final String gateway;
  final String appOrderId;
  final Map<String, dynamic> paymentPayload;

  Map<String, dynamic> toJson() {
    return {
      'gateway': gateway,
      'app_order_id': appOrderId,
      ...paymentPayload,
    };
  }
}

class ConfirmPaymentResponse {
  const ConfirmPaymentResponse({
    required this.orderId,
    required this.paymentId,
    required this.status,
  });

  final String orderId;
  final String paymentId;
  final String status;

  factory ConfirmPaymentResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmPaymentResponse(
      orderId: json['order_id']?.toString() ?? '',
      paymentId: json['payment_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'paid',
    );
  }
}
