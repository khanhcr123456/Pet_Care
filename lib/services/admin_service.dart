import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class AdminService {
  // --- Firebase Auth Users ---
  Future<List<dynamic>> getFirebaseUsers(String token, {int limit = 100}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/firebase/users?limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map) {
        if (decoded['users'] is List) return decoded['users'] as List;
        if (decoded['data'] is List) return decoded['data'] as List;
        if (decoded['data'] is Map && decoded['data']['users'] is List) return decoded['data']['users'] as List;
        if (decoded['items'] is List) return decoded['items'] as List;
      }
      return [];
    } else {
      throw Exception('Lỗi lấy Firebase users: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> disableFirebaseUser(String token, String uid, bool disabled) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/firebase/users/$uid/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'disabled': disabled}),
    );
    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
      throw Exception('Lỗi cập nhật trạng thái user: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> deleteFirebaseUser(String token, String uid) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/firebase/users/$uid'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
      throw Exception('Lỗi xoá user: ${response.statusCode} - ${response.body}');
    }
  }
}
