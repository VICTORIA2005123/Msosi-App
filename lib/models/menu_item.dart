class MenuItem {
  final int id;
  final int restaurantId;
  final String itemName;
  final double price;
  final bool available;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.itemName,
    required this.price,
    required this.available,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: int.parse(json['id'].toString()),
      restaurantId: int.parse(json['restaurant_id'].toString()),
      itemName: json['item_name'],
      price: double.parse(json['price'].toString()),
      available: json['available'] == 1 || json['available'] == true || json['available'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'item_name': itemName,
      'price': price,
      'available': available ? 1 : 0,
    };
  }
}
