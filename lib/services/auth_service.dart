import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pet_care/config/app_config.dart';
import 'package:pet_care/models/auth_session.dart';

class AuthService {
  Future<AuthSession> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid login response.');
    }

    return AuthSession.fromLoginPayload(decoded);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': name, // usually APIs use fullName or name
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Register failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch user info: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    return Map<String, dynamic>.from(data is Map ? data : {});
  }

  Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      // Log or handle error if needed, but usually we just proceed with local logout
      print('Logout API error: ${response.body}');
    }
  }

  Future<List<dynamic>> getVets({int page = 1, int limit = 20}) async {
    final response = await http.get(Uri.parse('${AppConfig.baseUrl}/auth/vets?page=$page&limit=$limit'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to fetch vets: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> updateData, {String? avatarPath}) async {
    if (avatarPath != null) {
      final request = http.MultipartRequest('PUT', Uri.parse('${AppConfig.baseUrl}/auth/profile'));
      request.headers['Authorization'] = 'Bearer $token';
      
      updateData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      final ext = avatarPath.split('.').last.toLowerCase();
      String subtype = 'jpeg';
      if (ext == 'png') subtype = 'png';
      else if (ext == 'gif') subtype = 'gif';
      else if (ext == 'webp') subtype = 'webp';
      else if (ext == 'jpg') subtype = 'jpeg';

      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        avatarPath,
        contentType: MediaType('image', subtype),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'] ?? decoded;
      return Map<String, dynamic>.from(data is Map ? data : {});
    } else {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'] ?? decoded;
      return Map<String, dynamic>.from(data is Map ? data : {});
    }
  }
}
