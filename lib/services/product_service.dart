import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class ProductService {
  Future<List<dynamic>> getProducts({
    bool inStock = true,
    String sortBy = '-createdAt',
    int page = 1,
    int limit = 20,
  }) async {
    final url = '${AppConfig.baseUrl}/products?inStock=$inStock&sortBy=$sortBy&page=$page&limit=$limit';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/products/$productId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<void> addToCart(String token, String productId, int quantity) async {
    final url = '${AppConfig.baseUrl}/products/$productId/cart';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'quantity': quantity}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add to cart: ${response.body}');
    }
  }

  Future<List<dynamic>> getCart(String token) async {
    final url = '${AppConfig.baseUrl}/products/cart';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load cart: ${response.body}');
    }
  }

  Future<void> updateCartQuantity(String token, String productId, int quantity) async {
    final url = '${AppConfig.baseUrl}/products/$productId/cart';
    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'quantity': quantity}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update cart: ${response.body}');
    }
  }

  Future<void> removeFromCart(String token, String productId) async {
    final url = '${AppConfig.baseUrl}/products/$productId/cart';
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from cart: ${response.body}');
    }
  }
}
