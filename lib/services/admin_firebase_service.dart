import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class AdminFirebaseService {
  final String _baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> getRemoteConfig(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/firebase/remote-config'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load Remote Config');
  }

  Future<void> updateRemoteConfigTheme(String token, String theme) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/firebase/remote-config'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'app_theme_event': theme}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update Remote Config Theme');
    }
  }

  Future<Map<String, dynamic>> getFcmBoard(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/firebase/fcm-board'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load FCM Board');
  }

  Future<Map<String, dynamic>> getAnalytics(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/firebase/analytics'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load Analytics');
  }

  Future<Map<String, dynamic>> getFirebaseUsers(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/firebase/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load Firebase Users');
  }

  Future<Map<String, dynamic>> sendNotificationAll({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/firebase/send-notification-all'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'body': body,
        'data': data ?? {},
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : {'message': response.body};
    }

    throw Exception('Failed to send notification');
  }
}
