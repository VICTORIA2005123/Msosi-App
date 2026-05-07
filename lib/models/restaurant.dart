class Restaurant {
  final String id;
  final String vendorId;
  final String name;
  final String location;
  final String openingHours;
  final String dietType;
  final String imageUrl;
  final bool isOpen;
  final int prepCapacity; // max orders per 10-min slot
  final bool isBusy;
  final String kitchenHeat; // 'Standard', 'Busy', 'Slammed'
  final int currentQueueCount;

  bool get isCurrentlyOpen {
    if (!isOpen) return false;
    try {
      final cleanHours = openingHours.replaceAll(' (BUSY)', '').replaceAll(RegExp(r'[^0-9:\-]'), '');
      final parts = cleanHours.split('-');
      if (parts.length != 2) return isOpen;
      
      final now = DateTime.now();
      final openParts = parts[0].split(':');
      final closeParts = parts[1].split(':');
      
      final openTime = DateTime(now.year, now.month, now.day, int.parse(openParts[0]), int.parse(openParts[1]));
      final closeTime = DateTime(now.year, now.month, now.day, int.parse(closeParts[0]), int.parse(closeParts[1]));
      
      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return isOpen;
    }
  }

  Restaurant({
    required this.id,
    this.vendorId = '',
    required this.name,
    required this.location,
    required this.openingHours,
    this.dietType = 'Both',
    this.imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
    this.isOpen = true,
    this.prepCapacity = 15,
    this.isBusy = false,
    this.kitchenHeat = 'Standard',
    this.currentQueueCount = 0,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'].toString(),
      vendorId: json['vendor_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Vendor',
      location: json['location']?.toString() ?? 'Unknown Location',
      openingHours: json['opening_hours']?.toString() ?? '08:00-20:00',
      dietType: json['diet_type']?.toString() ?? 'Both',
      imageUrl: json['image_url']?.toString() ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
      isOpen: json['is_open'] == true || json['is_open'] == 1 || json['is_open'] == '1' || json['is_open'] == null,
      prepCapacity: int.tryParse(json['prep_capacity']?.toString() ?? '15') ?? 15,
      isBusy: json['is_busy'] == 1 || json['is_busy'] == true || json['is_busy'] == '1',
      kitchenHeat: json['kitchen_heat']?.toString() ?? 'Standard',
      currentQueueCount: int.tryParse(json['current_queue_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'location': location,
      'opening_hours': openingHours,
      'diet_type': dietType,
      'image_url': imageUrl,
      'is_open': isOpen,
      'prep_capacity': prepCapacity,
      'is_busy': isBusy,
      'kitchen_heat': kitchenHeat,
      'current_queue_count': currentQueueCount,
    };
  }

  /// Data for Firestore document (excludes id).
  Map<String, dynamic> toFirestore() {
    return {
      'vendor_id': vendorId,
      'name': name,
      'location': location,
      'opening_hours': openingHours,
      'diet_type': dietType,
      'image_url': imageUrl,
      'is_open': isOpen,
      'prep_capacity': prepCapacity,
      'is_busy': isBusy,
      'kitchen_heat': kitchenHeat,
      'current_queue_count': currentQueueCount,
    };
  }

  Restaurant copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? location,
    String? openingHours,
    String? dietType,
    String? imageUrl,
    bool? isOpen,
    int? prepCapacity,
    bool? isBusy,
    String? kitchenHeat,
    int? currentQueueCount,
  }) {
    return Restaurant(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      location: location ?? this.location,
      openingHours: openingHours ?? this.openingHours,
      dietType: dietType ?? this.dietType,
      imageUrl: imageUrl ?? this.imageUrl,
      isOpen: isOpen ?? this.isOpen,
      prepCapacity: prepCapacity ?? this.prepCapacity,
      isBusy: isBusy ?? this.isBusy,
      kitchenHeat: kitchenHeat ?? this.kitchenHeat,
      currentQueueCount: currentQueueCount ?? this.currentQueueCount,
    );
  }
}
