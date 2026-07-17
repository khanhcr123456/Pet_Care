import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_care/config/app_config.dart';

class InvoiceService {
  Future<Map<String, dynamic>> createProductInvoice(String token, Map<String, dynamic> invoiceData) async {
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
    
    try {
      if (response.body.isNotEmpty) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> initSepayCheckout(String token, String invoiceId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/payments/sepay/checkout/init'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'invoiceId': invoiceId,
        'successUrl': 'https://petcare.app.vn/payment/success',
        'errorUrl': 'https://petcare.app.vn/payment/error',
        'cancelUrl': 'https://petcare.app.vn/payment/cancel',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Lỗi tạo mã QR thanh toán: ${response.body}');
    }
    
    try {
      if (response.body.isNotEmpty) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
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

  Future<void> updateInvoiceStatus(String token, String invoiceId, String status) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/invoices/$invoiceId/order-status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'orderStatus': status}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update invoice status: ${response.body}');
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
