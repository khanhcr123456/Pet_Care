import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  Future<List<dynamic>> getAllAppointments(String token, {int page = 1, int limit = 20, String? vetId, String? petId}) async {
    String url = '${AppConfig.baseUrl}/appointments/all?';
    if (vetId != null && vetId.isNotEmpty) {
      url += 'vet=$vetId&';
    }
    if (petId != null && petId.isNotEmpty) {
      url += 'petId=$petId&';
    }
    url += 'page=$page&limit=$limit';
    
    print('DEBUG API URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load all appointments: ${response.body}');
    }
  }

  Future<List<dynamic>> getVetAppointments(String token, {int page = 1, int limit = 100}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/appointments/vet?page=$page&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? decoded ?? [];
    } else {
      throw Exception('Failed to load vet appointments: ${response.body}');
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

  Future<void> updateAppointmentStatus(String token, String appointmentId, String status) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/appointments/$appointmentId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update appointment status: ${response.body}');
    }
  }

  Future<void> addVaccination(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/vaccinations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add vaccination: ${response.body}');
    }
  }

  Future<List<dynamic>> getVaccinationsByPetId(String token, String petId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/vaccinations/pet/$petId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load vaccinations: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getVaccinationById(String token, String id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/vaccinations/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? {};
    } else {
      throw Exception('Failed to load vaccination: ${response.body}');
    }
  }

  Future<String?> addHealthRecord(String token, Map<String, dynamic> payload, {List<String>? imagePaths}) async {
    final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/health-records'));
    request.headers['Authorization'] = 'Bearer $token';
    
    payload.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });
    
    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (int i = 0; i < imagePaths.length; i++) {
        final path = imagePaths[i];
        final ext = path.split('.').last.toLowerCase();
        String subtype = 'jpeg';
        if (ext == 'png') subtype = 'png';
        else if (ext == 'gif') subtype = 'gif';
        else if (ext == 'webp') subtype = 'webp';
        
        request.files.add(await http.MultipartFile.fromPath(
          'images', 
          path,
          contentType: MediaType('image', subtype),
        ));
      }
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add health record: ${response.body}');
    }
    
    // Return the new health record ID
    try {
      final decoded = json.decode(response.body);
      return (decoded['data']?['_id'] ?? decoded['data']?['id'] ?? decoded['_id'] ?? decoded['id'])?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getHealthRecordsByPetId(String token, String petId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/health-records/pet/$petId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load health records: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getHealthRecordById(String token, String id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/health-records/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? {};
    } else {
      throw Exception('Failed to load health record: ${response.body}');
    }
  }
}
