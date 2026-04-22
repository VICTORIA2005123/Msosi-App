import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch all restaurants
  Future<List<Restaurant>> getRestaurants() async {
    try {
      final snapshot = await _db.collection('restaurants').get();
      return snapshot.docs.map<Restaurant>((doc) {
        var data = doc.data();
        data['id'] = doc.id; // Map the doc ID
        return Restaurant.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load restaurants from Firestore: $e');
    }
  }

  // Fetch menu items for a specific restaurant
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

  // Place a new order
  Future<Map<String, dynamic>> placeOrder(String userId, String restaurantId, double total, List<Map<String, dynamic>> items) async {
    try {
      final docRef = await _db.collection('orders').add({
        'user_id': userId,
        'restaurant_id': restaurantId,
        'total_price': total,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
        'items': items,
      });
      return {'success': true, 'orderId': docRef.id};
    } catch (e) {
      throw Exception('Error placing order: $e');
    }
  }

  // Fetch orders for a specific user
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

      // Sort client-side to avoid requiring a composite Firestore index
      // on (user_id, created_at) during development.
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }
}
