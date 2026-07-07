import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class BookingService {
  Future<void> bookAppointment(String token, Map<String, dynamic> appointmentData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/appointments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(appointmentData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to book appointment: ${response.body}');
    }
  }

  Future<List<Map<String, String>>> getAvailableSlots(String token, String vetId, String date) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/appointments/available-slots?vetId=$vetId&date=$date'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['slots'] is List) {
        final List<dynamic> daySlots = decoded['slots'];
        return daySlots
            .where((s) => s['available'] == true)
            .map<Map<String, String>>((s) => {
                  'startTime': s['startTime'] as String,
                  'endTime': s['endTime'] as String,
                })
            .toList();
      } else if (decoded['slots'] is Map) {
        final slotsObj = decoded['slots'] as Map<String, dynamic>;
        if (slotsObj.containsKey(date)) {
          final List<dynamic> daySlots = slotsObj[date];
          return daySlots
              .where((s) => s['available'] == true)
              .map<Map<String, String>>((s) => {
                    'startTime': s['startTime'] as String,
                    'endTime': s['endTime'] as String,
                  })
              .toList();
        }
      }
    }

    return <Map<String, String>>[];
  }

  Future<List<dynamic>> getAppointments(String token, {int page = 1, int limit = 20}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/appointments?page=$page&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load appointments: ${response.body}');
    }
  }

  Future<void> cancelAppointment(String token, String appointmentId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/appointments/$appointmentId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
      throw Exception('Failed to cancel appointment: ${response.body}');
    }
  }
}
