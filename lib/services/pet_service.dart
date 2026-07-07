import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pet_care/config/app_config.dart';

class PetService {
  Future<List<dynamic>> getServices({int page = 1, int limit = 20, String sortBy = '-createdAt'}) async {
    final response = await http.get(Uri.parse('${AppConfig.baseUrl}/services?sortBy=$sortBy&page=$page&limit=$limit'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<dynamic>> getPets(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/pets'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load pets');
    }
  }

  Future<Map<String, dynamic>> addPet(String token, Map<String, dynamic> petData, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/pets'));
      request.headers['Authorization'] = 'Bearer $token';
      
      petData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });
      
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'png' : ((ext == 'gif') ? 'gif' : ((ext == 'webp') ? 'webp' : 'jpeg'));
      
      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: MediaType('image', mimeType)
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add pet with image: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    } else {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/pets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(petData),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add pet: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    }
  }

  Future<Map<String, dynamic>> getPetById(String token, String id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/pets/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? {};
    } else {
      throw Exception('Failed to load pet details');
    }
  }

  Future<void> updatePet(String token, String id, Map<String, dynamic> petData, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('PUT', Uri.parse('${AppConfig.baseUrl}/pets/$id'));
      request.headers['Authorization'] = 'Bearer $token';
      
      petData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });
      
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'png' : ((ext == 'gif') ? 'gif' : ((ext == 'webp') ? 'webp' : 'jpeg'));
      
      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: MediaType('image', mimeType)
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update pet with image: ${response.body}');
      }
    } else {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/pets/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(petData),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update pet: ${response.body}');
      }
    }
  }

  Future<void> deletePet(String token, String id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/pets/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete pet: ${response.body}');
    }
  }
}
