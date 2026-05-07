class MenuItem {
  final String id;
  final String restaurantId;
  final String itemName;
  final double price;
  final int prepTime; // preparation time in minutes
  final bool available;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.itemName,
    required this.price,
    this.prepTime = 15,
    required this.available,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(),
      restaurantId: json['restaurant_id'].toString(),
      itemName: json['item_name'],
      price: double.parse(json['price'].toString()),
      prepTime: int.tryParse(json['prep_time']?.toString() ?? '15') ?? 15,
      available: json['available'] == 1 || json['available'] == true || json['available'] == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'item_name': itemName,
      'price': price,
      'prep_time': prepTime,
      'available': available ? 1 : 0,
    };
  }

  /// Data for Firestore document (excludes id and restaurant_id which are path-based).
  Map<String, dynamic> toFirestore() {
    return {
      'item_name': itemName,
      'price': price,
      'prep_time': prepTime,
      'available': available,
    };
  }

  MenuItem copyWith({
    String? id,
    String? restaurantId,
    String? itemName,
    double? price,
    int? prepTime,
    bool? available,
  }) {
    return MenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      prepTime: prepTime ?? this.prepTime,
      available: available ?? this.available,
    );
  }
}
