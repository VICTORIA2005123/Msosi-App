class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final DateTime? pickupTime;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.pickupTime,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    List<OrderItem> itemsList = list.map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList();

    return Order(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      restaurantId: json['restaurant_id'].toString(),
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: _parseDateTime(json['created_at']),
      pickupTime: json['pickup_time'] != null ? _parseDateTime(json['pickup_time']) : null,
      items: itemsList,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    // Handle Firestore Timestamp
    if (value != null && value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  /// Human-readable status label.
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready for Pickup';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String menuId;
  final int quantity;
  final double price;
  final String? itemName; // Optional for UI display

  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuId,
    required this.quantity,
    required this.price,
    this.itemName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      menuId: json['menu_id']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      itemName: json['item_name'],
    );
  }
}
