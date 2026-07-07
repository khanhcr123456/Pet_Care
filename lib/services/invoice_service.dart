import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class InvoiceService {
  Future<void> createProductInvoice(String token, Map<String, dynamic> invoiceData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/invoices/products'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(invoiceData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create invoice: ${response.body}');
    }
  }

  Future<List<dynamic>> getInvoices(String token, {int page = 1, int limit = 20}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/invoices?page=$page&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load invoices: ${response.body}');
    }
  }

  Future<void> cancelInvoice(String token, String invoiceId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/invoices/$invoiceId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to cancel invoice: ${response.body}');
    }
  }
}
