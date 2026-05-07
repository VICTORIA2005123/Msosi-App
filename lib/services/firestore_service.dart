import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final firestoreServiceProvider = Provider((ref) {
  return FirestoreService(ref: ref);
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Ref? ref;

  FirestoreService({this.ref});

  // ─── RESTAURANTS ───────────────────────────────────────────

  /// Fetch all restaurants.
  Future<List<Restaurant>> getRestaurants() async {
    try {
      final snapshot = await _db.collection('restaurants').get();
      return snapshot.docs.map<Restaurant>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return Restaurant.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load restaurants from Firestore: $e');
    }
  }

  /// Fetch restaurants owned by a specific vendor.
  Future<List<Restaurant>> getVendorRestaurants(String vendorId) async {
    try {
      final snapshot = await _db
          .collection('restaurants')
          .where('vendor_id', isEqualTo: vendorId)
          .get();
      return snapshot.docs.map<Restaurant>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return Restaurant.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load vendor restaurants: $e');
    }
  }

  /// Create a new restaurant for a vendor.
  Future<String> createRestaurant(Restaurant restaurant) async {
    try {
      final docRef = await _db.collection('restaurants').add(restaurant.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create restaurant: $e');
    }
  }

  /// Update restaurant details.
  Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> data) async {
    try {
      await _db.collection('restaurants').doc(restaurantId).update(data);
    } catch (e) {
      throw Exception('Failed to update restaurant: $e');
    }
  }

  // ─── MENU ITEMS ────────────────────────────────────────────

  /// Fetch menu items for a specific restaurant.
  Future<List<MenuItem>> getMenu(String restaurantId) async {
    try {
      final snapshot = await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .get();

      return snapshot.docs.map<MenuItem>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        data['restaurant_id'] = restaurantId;
        return MenuItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load menu: $e');
    }
  }

  /// Add a new menu item to a restaurant.
  Future<String> addMenuItem(String restaurantId, MenuItem item) async {
    try {
      final docRef = await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .add(item.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add menu item: $e');
    }
  }

  /// Update an existing menu item.
  Future<void> updateMenuItem(String restaurantId, String itemId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .doc(itemId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete a menu item.
  Future<void> deleteMenuItem(String restaurantId, String itemId) async {
    try {
      await _db
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .doc(itemId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete menu item: $e');
    }
  }

  /// Toggle menu item availability.
  Future<void> toggleItemAvailability(String restaurantId, String itemId, bool available) async {
    await updateMenuItem(restaurantId, itemId, {'available': available});
  }

  // ─── ORDERS ────────────────────────────────────────────────

  /// Place a new order via secure Cloud Function.
  Future<Map<String, dynamic>> placeOrder(
    String userId,
    String restaurantId,
    double total,
    List<Map<String, dynamic>> items, {
    DateTime? pickupTime,
  }) async {
    try {
      if (ref == null) throw Exception('Ref required for secure API call');
      final token = await ref!.read(authServiceProvider).getToken();
      
      final url = Uri.parse('${AppConfig.apiBaseUrl}/orders/create');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'restaurant_id': restaurantId,
          'pickup_time': pickupTime?.toIso8601String(),
          'items': items,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data as Map<String, dynamic>;
      } else {
        throw Exception(data['error'] ?? 'Failed to place order');
      }
    } catch (e) {
      throw Exception('Error placing order: $e');
    }
  }

  /// Fetch orders for a specific user.
  Future<List<Order>> getOrders(String userId) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('user_id', isEqualTo: userId)
          .get();

      final orders = snapshot.docs.map<Order>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return Order.fromJson(data);
      }).toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  /// Stream orders for a specific user.
  Stream<List<Order>> streamUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map<Order>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return Order.fromJson(data);
      }).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Stream orders for a vendor's restaurant (real-time).
  Stream<List<Order>> streamVendorOrders(String restaurantId) {
    return _db
        .collection('orders')
        .where('restaurant_id', isEqualTo: restaurantId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map<Order>((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return Order.fromJson(data);
      }).toList();
      // Most recent first, active orders on top
      orders.sort((a, b) {
        const statusOrder = {'pending': 0, 'preparing': 1, 'ready': 2, 'completed': 3};
        final aOrder = statusOrder[a.status.toLowerCase()] ?? 4;
        final bOrder = statusOrder[b.status.toLowerCase()] ?? 4;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return b.createdAt.compareTo(a.createdAt);
      });
      return orders;
    });
  }

  /// Update order status with allowed transitions.
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    const allowedTransitions = {
      'pending': ['preparing'],
      'preparing': ['ready'],
      'ready': ['completed'],
    };

    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) throw Exception('Order not found');

      final currentStatus = (doc.data()?['status'] as String?)?.toLowerCase() ?? '';
      final allowed = allowedTransitions[currentStatus] ?? [];

      if (!allowed.contains(newStatus.toLowerCase())) {
        throw Exception('Cannot transition from "$currentStatus" to "$newStatus"');
      }

      await _db.collection('orders').doc(orderId).update({
        'status': newStatus.toLowerCase(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Count orders in a time window for capacity checking.
  Future<int> countOrdersInSlot(String restaurantId, DateTime slotStart, DateTime slotEnd) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('restaurant_id', isEqualTo: restaurantId)
          .where('pickup_time', isGreaterThanOrEqualTo: slotStart.toIso8601String())
          .where('pickup_time', isLessThan: slotEnd.toIso8601String())
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0; // Fail open for capacity check
    }
  }
}
