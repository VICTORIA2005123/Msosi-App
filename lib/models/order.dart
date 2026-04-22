class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    List<OrderItem> itemsList = list.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      restaurantId: json['restaurant_id'].toString(),
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      items: itemsList,
    );
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
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      menuId: json['menu_id'].toString(),
      quantity: int.parse(json['quantity'].toString()),
      price: double.parse(json['price'].toString()),
      itemName: json['item_name'],
    );
  }
}
