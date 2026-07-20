import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';
import 'package:pet_care/utils/responsive.dart';

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
  String _selectedPaymentMethod = 'cod';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  final num _shippingFee = 30000;
  bool _isProcessing = false;
  
  bool _nameError = false;
  String? _phoneErrorMsg;
  bool _addressError = false;

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
    final phoneText = _phoneController.text.trim();
    String? phoneError;
    if (phoneText.isEmpty) {
      phoneError = 'Vui lòng nhập số điện thoại';
    } else if (!RegExp(r'^(03|05|07|08|09)\d{8}$').hasMatch(phoneText)) {
      phoneError = 'Số điện thoại không hợp lệ';
    }

    setState(() {
      _nameError = _nameController.text.trim().isEmpty;
      _phoneErrorMsg = phoneError;
      _addressError = _addressController.text.trim().isEmpty;
    });

    if (_nameError || _phoneErrorMsg != null || _addressError) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng kiểm tra lại thông tin nhận hàng')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final invoiceData = {
        'products': widget.selectedItems.map((item) {
          final product = item['product'] ?? {};
          return {
            'productId': product['_id'] ?? product['id'],
            'quantity': item['quantity'] ?? 1,
          };
        }).toList(),
        'currency': 'VND',
        'address': _addressController.text.trim(),
        'recipientPhone': _phoneController.text.trim(),
        'recipientName': _nameController.text.trim(),
        'dueDate': DateTime.now().toIso8601String().split('T')[0],
        'paymentMethod': _selectedPaymentMethod,
      };

      final invoiceRes = await InvoiceService().createProductInvoice(widget.user['token'], invoiceData);

      // Remove ordered items from cart
      for (var item in widget.selectedItems) {
        final product = item['product'] ?? {};
        final productId = product['_id'] ?? product['id'];
        if (productId != null) {
          try {
            await ProductService().removeFromCart(widget.user['token'], productId);
          } catch (e) {
            debugPrint('Failed to remove item from cart: $e');
          }
        }
      }

    if (mounted) {
      setState(() => _isProcessing = false);
      
      if (_selectedPaymentMethod == 'bank') {
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
                Text('Đặt hàng thành công!', style: TextStyle(fontSize: R.sp(context, 19), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
                const SizedBox(height: 8),
                Text('Vui lòng thanh toán đơn hàng này để shop có thể đối soát và lên đơn cho bạn nhé.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final invoiceIdObj = invoiceRes['data'] != null ? invoiceRes['data']['_id'] ?? invoiceRes['data']['id'] : invoiceRes['_id'] ?? invoiceRes['id'];
                      final invoiceId = invoiceIdObj?.toString() ?? '';
                      if (invoiceId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy mã đơn hàng. Vui lòng vào Lịch sử để thanh toán.')));
                        return;
                      }

                      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                      try {
                        final res = await InvoiceService().initSepayCheckout(widget.user['token'], invoiceId);
                        if (!mounted) return;
                        Navigator.pop(context); // close loading
                        
                        final paymentData = (res['data'] is Map) ? res['data'] : res;
                        String? paymentUrl = res['checkoutPageUrl'] ?? res['url'] ?? paymentData['checkoutPageUrl'] ?? paymentData['url'] ?? paymentData['paymentUrl'];
                        
                        if (paymentUrl != null && paymentUrl.isNotEmpty) {
                           await Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => Scaffold(
                                 appBar: AppBar(
                                   title: const Text('Cổng thanh toán', style: TextStyle(color: Colors.white)),
                                   backgroundColor: const Color(0xFF0F2E53),
                                   leading: IconButton(
                                     icon: const Icon(Icons.close, color: Colors.white),
                                     onPressed: () => Navigator.pop(context),
                                   ),
                                 ),
                                 body: _WebViewLoader(url: paymentUrl),
                               ),
                             )
                           );
                           if (!mounted) return;
                           Navigator.of(context).popUntil((route) => route.isFirst);
                           Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseHistoryScreen(user: widget.user)));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy link thanh toán (checkoutPageUrl). Vui lòng thử lại sau.')));
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải thanh toán: ${e.toString().replaceAll('Exception: ', '')}')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF07E2B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('THANH TOÁN TẠI ĐÂY', style: TextStyle(fontSize: R.sp(context, 14))),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F2E53),
                      side: const BorderSide(color: Color(0xFF0F2E53)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('ĐỂ SAU', style: TextStyle(fontSize: R.sp(context, 14))),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      
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
              Text('Đặt hàng thành công!', style: TextStyle(fontSize: R.sp(context, 19), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
              const SizedBox(height: 8),
              Text('Cảm ơn bạn đã mua sắm tại PetCare.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
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
                  child: Text('VỀ TRANG CHỦ', style: TextStyle(fontSize: R.sp(context, 14))),
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
                  child: Text('XEM ĐƠN HÀNG', style: TextStyle(fontSize: R.sp(context, 14))),
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
    final hPad = R.hPad(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(
          'Đặt hàng',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin giao hàng
            Text('Thông tin nhận hàng', style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
            SizedBox(height: R.isSmall(context) ? 8 : 12),
            Container(
              padding: EdgeInsets.all(hPad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    onChanged: (_) {
                      if (_nameError) setState(() => _nameError = false);
                    },
                    style: TextStyle(fontSize: R.sp(context, 14)),
                    decoration: InputDecoration(
                      labelText: 'Họ và tên',
                      errorText: _nameError ? 'Vui lòng nhập họ và tên' : null,
                      labelStyle: TextStyle(fontSize: R.sp(context, 13)),
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) {
                      if (_phoneErrorMsg != null) setState(() => _phoneErrorMsg = null);
                    },
                    style: TextStyle(fontSize: R.sp(context, 14)),
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      errorText: _phoneErrorMsg,
                      labelStyle: TextStyle(fontSize: R.sp(context, 13)),
                      prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    minLines: 1,
                    maxLines: null,
                    onChanged: (_) {
                      if (_addressError) setState(() => _addressError = false);
                    },
                    style: TextStyle(fontSize: R.sp(context, 14)),
                    decoration: InputDecoration(
                      labelText: 'Địa chỉ giao hàng',
                      errorText: _addressError ? 'Vui lòng nhập địa chỉ' : null,
                      labelStyle: TextStyle(fontSize: R.sp(context, 13)),
                      prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: R.isSmall(context) ? 18 : 24),

            // Phương thức thanh toán
            Text('Phương thức thanh toán',
                style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
            SizedBox(height: R.isSmall(context) ? 8 : 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'cod'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'cod'
                            ? const Color(0xFF0F2E53).withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'cod'
                              ? const Color(0xFF0F2E53)
                              : Colors.grey.shade300,
                          width: _selectedPaymentMethod == 'cod' ? 2 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              color: _selectedPaymentMethod == 'cod' ? const Color(0xFF0F2E53) : Colors.grey,
                              size: 28),
                          const SizedBox(height: 6),
                          Text('Thanh toán\nkhi nhận hàng',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: R.sp(context, 12),
                                fontWeight: _selectedPaymentMethod == 'cod' ? FontWeight.bold : FontWeight.normal,
                                color: _selectedPaymentMethod == 'cod' ? const Color(0xFF0F2E53) : Colors.grey,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaymentMethod = 'bank'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'bank'
                            ? const Color(0xFFF07E2B).withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'bank'
                              ? const Color(0xFFF07E2B)
                              : Colors.grey.shade300,
                          width: _selectedPaymentMethod == 'bank' ? 2 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_outlined,
                              color: _selectedPaymentMethod == 'bank' ? const Color(0xFFF07E2B) : Colors.grey,
                              size: 28),
                          const SizedBox(height: 6),
                          Text('Chuyển khoản\nngân hàng',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: R.sp(context, 12),
                                fontWeight: _selectedPaymentMethod == 'bank' ? FontWeight.bold : FontWeight.normal,
                                color: _selectedPaymentMethod == 'bank' ? const Color(0xFFF07E2B) : Colors.grey,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.isSmall(context) ? 18 : 24),

            // Danh sách sản phẩm
            Text('Sản phẩm đã chọn', style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
            SizedBox(height: R.isSmall(context) ? 8 : 12),
            ...widget.selectedItems.map((item) {
              final product = item['product'] ?? {};
              final images = product['images'] as List<dynamic>?;
              final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url'] : null;
              final quantity = item['quantity'] ?? 1;
              final price = product['price'] ?? 0;
              final imgSize = R.isSmall(context) ? 52.0 : 60.0;

              return Container(
                margin: EdgeInsets.only(bottom: R.isSmall(context) ? 10 : 12),
                padding: EdgeInsets.all(R.isSmall(context) ? 10 : 12),
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
                          ? Image.network(imageUrl, width: imgSize, height: imgSize, fit: BoxFit.cover)
                          : Container(width: imgSize, height: imgSize, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name'] ?? 'Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13), color: const Color(0xFF0F2E53)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatCurrency(price), style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFF07E2B), fontSize: R.sp(context, 13))),
                              Text('x$quantity', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 12))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: R.isSmall(context) ? 18 : 24),

            // Tổng kết
            Container(
              padding: EdgeInsets.all(hPad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF07E2B).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng thanh toán:', style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
                  Text(formatCurrency(widget.totalAmount), style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: const Color(0xFFF07E2B))),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(R.hPad(context) + 4),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: R.isSmall(context) ? 46 : 50,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2E53),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('ĐẶT HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 15))),
          ),
        ),
      ),
    );
  }
}

class _WebViewLoader extends StatefulWidget {
  final String url;
  const _WebViewLoader({required this.url});
  @override
  State<_WebViewLoader> createState() => _WebViewLoaderState();
}

class _WebViewLoaderState extends State<_WebViewLoader> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://petcare.app.vn/payment/')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller);
  }
}
