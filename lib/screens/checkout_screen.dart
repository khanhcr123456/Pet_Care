import 'package:flutter/material.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<dynamic> selectedItems;
  final num totalAmount;

  const CheckoutScreen({
    super.key,
    required this.user,
    required this.selectedItems,
    required this.totalAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = 'COD';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  final num _shippingFee = 30000;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user['name'] ?? widget.user['fullName'] ?? widget.user['username'] ?? '';
    _phoneController.text = widget.user['phone'] ?? '';
    _addressController.text = widget.user['address'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String formatCurrency(num amount) {
    final str = amount.toInt().toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      count++;
      result = str[i] + result;
      if (count % 3 == 0 && i != 0) {
        result = '.$result';
      }
    }
    return '$result đ';
  }

  void _placeOrder() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin nhận hàng')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final invoiceData = {
        'receiverName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'paymentMethod': _selectedPaymentMethod,
        'shippingFee': _shippingFee,
        'totalAmount': widget.totalAmount + _shippingFee,
        'products': widget.selectedItems.map((item) {
          final product = item['product'] ?? {};
          return {
            'productId': product['_id'] ?? product['id'],
            'quantity': item['quantity'] ?? 1,
            'price': product['price'] ?? 0,
          };
        }).toList(),
      };

      await InvoiceService().createProductInvoice(widget.user['token'], invoiceData);

    if (mounted) {
      setState(() => _isProcessing = false);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text('Đặt hàng thành công!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
              const SizedBox(height: 8),
              const Text('Cảm ơn bạn đã mua sắm tại PawRent.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2E53),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('VỀ TRANG CHỦ'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PurchaseHistoryScreen(user: widget.user)),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF07E2B),
                    side: const BorderSide(color: Color(0xFFF07E2B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('XEM ĐƠN HÀNG'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đặt hàng: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Thanh toán', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin giao hàng
            const Text('Thông tin nhận hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    minLines: 1,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ giao hàng',
                      prefixIcon: Icon(Icons.location_on, color: Colors.grey),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danh sách sản phẩm
            const Text('Sản phẩm đã chọn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
            const SizedBox(height: 12),
            ...widget.selectedItems.map((item) {
              final product = item['product'] ?? {};
              final images = product['images'] as List<dynamic>?;
              final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url'] : null;
              final quantity = item['quantity'] ?? 1;
              final price = product['price'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                          : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name'] ?? 'Sản phẩm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2E53)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF07E2B))),
                              Text('x$quantity', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Tổng kết
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF07E2B).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                  Text(formatCurrency(widget.totalAmount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF07E2B))),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2E53),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ĐẶT HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
