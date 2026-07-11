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

  Future<Map<String, dynamic>> addService(String token, Map<String, dynamic> data, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/services'));
      request.headers['Authorization'] = 'Bearer $token';
      
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
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
        throw Exception('Failed to add service with image: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    } else {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add service: ${response.body}');
      }
      final responseData = json.decode(response.body);
      return responseData['data'] ?? {};
    }
  }

  Future<void> updateService(String token, String id, Map<String, dynamic> data, {File? imageFile}) async {
    if (imageFile != null) {
      final request = http.MultipartRequest('PUT', Uri.parse('${AppConfig.baseUrl}/services/$id'));
      request.headers['Authorization'] = 'Bearer $token';
      
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
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
        throw Exception('Failed to update service with image: ${response.body}');
      }
    } else {
      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/services/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        // fallback to put if patch is not allowed
        if (response.statusCode == 404 || response.statusCode == 405) {
          final putResponse = await http.put(
            Uri.parse('${AppConfig.baseUrl}/services/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(data),
          );
          if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
             throw Exception('Failed to update service: ${putResponse.body}');
          }
          return;
        }
        throw Exception('Failed to update service: ${response.body}');
      }
    }
  }

  Future<List<dynamic>> getAllPets(String token, {int page = 1, int limit = 20}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/pets/all?page=$page&limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final data = decoded['data'];
      if (data is List) return data;
      if (data is Map) {
        if (data.containsKey('docs')) return data['docs'] as List<dynamic>;
        if (data.containsKey('pets')) return data['pets'] as List<dynamic>;
        if (data.containsKey('data')) return data['data'] as List<dynamic>;
      }
      return [];
    } else {
      throw Exception('Failed to load all pets');
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
      Uri.parse('${AppConfig.baseUrl}/pets/info/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? {};
    } else {
      throw Exception('Failed to load pet details (Status ${response.statusCode}): ${response.body}');
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

  Future<void> deleteService(String token, String id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/services/$id/permanent'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete service: ${response.body}');
    }
  }
}
