import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  Future<Map<String, dynamic>> addProduct(String token, Map<String, dynamic> data, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/products'));
      request.headers['Authorization'] = 'Bearer $token';
      
      data.forEach((key, value) {
        if (value != null) {
          if (value is Map || value is List) {
             request.fields[key] = json.encode(value);
          } else {
             request.fields[key] = value.toString();
          }
        }
      });
      
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'png' : ((ext == 'gif') ? 'gif' : ((ext == 'webp') ? 'webp' : 'jpeg'));
      
      request.files.add(await http.MultipartFile.fromPath(
        'images', 
        imageFile.path,
        contentType: MediaType('image', mimeType)
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add product with image: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    } else {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add product: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    }
  }

  Future<void> updateProduct(String token, String id, Map<String, dynamic> data, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('PUT', Uri.parse('${AppConfig.baseUrl}/products/$id'));
      request.headers['Authorization'] = 'Bearer $token';
      
      data.forEach((key, value) {
        if (value != null) {
          if (value is Map || value is List) {
             request.fields[key] = json.encode(value);
          } else {
             request.fields[key] = value.toString();
          }
        }
      });
      
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'png' : ((ext == 'gif') ? 'gif' : ((ext == 'webp') ? 'webp' : 'jpeg'));
      
      request.files.add(await http.MultipartFile.fromPath(
        'images', 
        imageFile.path,
        contentType: MediaType('image', mimeType)
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update product with image: ${response.body}');
      }
    } else {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/products/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update product: ${response.body}');
      }
    }
  }

  Future<void> deleteProduct(String token, String id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/products/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete product: ${response.body}');
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
