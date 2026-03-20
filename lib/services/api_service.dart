import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

class ApiService {
  static const String baseUrl = 'http://your-campus-api.com/api'; // Replace with actual PHP backend URL

  final http.Client _client = http.Client();

  Future<List<Restaurant>> getRestaurants() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/restaurants'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Restaurant.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load restaurants');
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [
        Restaurant(
          id: 1, name: 'Campus Diner', location: 'Central Plaza', openingHours: '08:00 - 20:00', dietType: 'Both',
          imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        ),
        Restaurant(
          id: 2, name: 'Green Bowl', location: 'Science Block', openingHours: '09:00 - 18:00', dietType: 'Veg',
          imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        ),
        Restaurant(
          id: 3, name: 'Meat Lovers Grille', location: 'East Wing', openingHours: '11:00 - 22:00', dietType: 'Non-Veg',
          imageUrl: 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        ),
      ];
    }
  }

  Future<List<MenuItem>> getMenu(int restaurantId) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/menu/$restaurantId'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => MenuItem.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load menu');
      }
    } catch (e) {
      throw Exception('Error fetching menu: $e');
    }
  }

  Future<Map<String, dynamic>> placeOrder(int userId, int restaurantId, double total, List<Map<String, dynamic>> items) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'restaurant_id': restaurantId,
          'total_price': total,
          'items': items,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Error placing order: $e');
    }
  }

  Future<List<Order>> getOrders(int userId) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/orders/$userId'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Order.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }
}
