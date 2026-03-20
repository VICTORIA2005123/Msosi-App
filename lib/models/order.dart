import 'menu_item.dart';

class Order {
  final int id;
  final int userId;
  final int restaurantId;
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
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      restaurantId: int.parse(json['restaurant_id'].toString()),
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      items: itemsList,
    );
  }
}

class OrderItem {
  final int id;
  final int orderId;
  final int menuId;
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
      id: int.parse(json['id'].toString()),
      orderId: int.parse(json['order_id'].toString()),
      menuId: int.parse(json['menu_id'].toString()),
      quantity: int.parse(json['quantity'].toString()),
      price: double.parse(json['price'].toString()),
      itemName: json['item_name'],
    );
  }
}
