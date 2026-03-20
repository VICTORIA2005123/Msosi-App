class Restaurant {
  final int id;
  final String name;
  final String location;
  final String openingHours;
  final String dietType; // e.g. 'Veg', 'Non-Veg', 'Both'
  final String imageUrl;

  Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.openingHours,
    this.dietType = 'Both',
    this.imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: int.parse(json['id'].toString()),
      name: json['name'],
      location: json['location'],
      openingHours: json['opening_hours'],
      dietType: json['diet_type'] ?? 'Both',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'opening_hours': openingHours,
      'diet_type': dietType,
      'image_url': imageUrl,
    };
  }
}
