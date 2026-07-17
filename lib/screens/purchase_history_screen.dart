import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:intl/intl.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PurchaseHistoryScreen({super.key, required this.user});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  Map<String, dynamic> _productCache = {};

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    try {
      final data = await InvoiceService().getInvoices(widget.user['token']);
      
      final productInvoices = data.where((inv) {
        final items = [
          ...(inv['items'] ?? []),
          ...(inv['products'] ?? []),
          ...(inv['services'] ?? []),
          ...(inv['packages'] ?? [])
        ];
        return items.any((item) => item is Map && item['type']?.toString().toLowerCase() == 'product');
      }).toList();

      if (mounted) {
        setState(() {
          _invoices = productInvoices;
          _isLoading = false;
        });
      }

      _fetchProductImages(productInvoices);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải lịch sử: $e')));
      }
    }
  }

  Future<void> _fetchProductImages(List<dynamic> invoices) async {
    final Set<String> productIds = {};
    for (final invoice in invoices) {
      final items = [
        ...(invoice['items'] ?? []),
        ...(invoice['products'] ?? []),
        ...(invoice['services'] ?? []),
        ...(invoice['packages'] ?? [])
      ];
      for (final p in items) {
        if (p is Map) {
          final refId = p['refId']?.toString();
          if (refId != null && refId.isNotEmpty && !_productCache.containsKey(refId)) {
            productIds.add(refId);
          }
        }
      }
    }

    if (productIds.isEmpty) return;

    final results = await Future.wait(
      productIds.map((id) => ProductService().getProductById(id)),
    );

    final Map<String, dynamic> newCache = Map.from(_productCache);
    int i = 0;
    for (final id in productIds) {
      if (results[i] != null) newCache[id] = results[i]!;
      i++;
    }

    if (mounted) {
      setState(() => _productCache = newCache);
    }
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

  @override
  Widget build(BuildContext context) {
    final hPad = R.hPad(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(
          'Lịch sử mua hàng',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
          : _invoices.isEmpty
              ? Center(child: Text('Chưa có đơn hàng nào', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14))))
              : ListView.builder(
                  padding: EdgeInsets.all(hPad),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    final rawStatus = invoice['orderStatus'] ?? invoice['status'] ?? 'pending';
                    final status = rawStatus.toString().toLowerCase();
                    final dateObj = invoice['createdAt'] != null ? DateTime.tryParse(invoice['createdAt'])?.toLocal() : null;
                    final date = dateObj != null ? DateFormat('dd/MM/yyyy HH:mm').format(dateObj) : '';
                        
                    Color statusColor = Colors.orange;
                    String statusText = 'Chờ xử lý';
                    if (status == 'completed' || status == 'success') {
                      statusColor = Colors.green;
                      statusText = 'Hoàn thành';
                    } else if (status == 'cancelled') {
                      statusColor = Colors.red;
                      statusText = 'Đã hủy';
                    } else if (status == 'confirmed') {
                      statusColor = Colors.blue;
                      statusText = 'Đã xác nhận';
                    } else if (status == 'preparing') {
                      statusColor = Colors.amber;
                      statusText = 'Đang chuẩn bị';
                    } else if (status == 'shipping') {
                      statusColor = Colors.deepPurple;
                      statusText = 'Đang giao hàng';
                    } else if (status == 'delivered') {
                      statusColor = Colors.teal;
                      statusText = 'Đã giao';
                    }

                    final address = invoice['address'] ?? 'Chưa cập nhật';
                    final orderId = invoice['_id'] ?? invoice['id'] ?? '';
                    final shortOrderId = orderId.toString().length > 8 ? orderId.toString().substring(0, 8).toUpperCase() : orderId.toString().toUpperCase();
                    
                    final rawPaymentMethod = invoice['paymentMethod']?.toString().toLowerCase();
                    String paymentMethodText = 'Thanh toán trực tiếp'; // Mặc định nếu API không trả về
                    if (rawPaymentMethod == 'cod') {
                      paymentMethodText = 'Thanh toán khi nhận hàng';
                    } else if (rawPaymentMethod == 'bank') {
                      paymentMethodText = 'Chuyển khoản';
                    } else if (rawPaymentMethod != null && rawPaymentMethod.isNotEmpty) {
                      paymentMethodText = invoice['paymentMethod'].toString();
                    }
                    
                    final total = invoice['total'] ?? invoice['totalAmount'] ?? 0;
                    final allItems = [
                      ...(invoice['items'] ?? []),
                      ...(invoice['products'] ?? []),
                      ...(invoice['services'] ?? []),
                      ...(invoice['packages'] ?? [])
                    ];
                    final invoiceItems = allItems.where((i) => i is Map && i['type']?.toString().toLowerCase() == 'product').toList();

                    return Card(
                      margin: EdgeInsets.only(bottom: R.isSmall(context) ? 10 : 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Thời gian: $date',
                                    style: TextStyle(color: const Color(0xFF0F2E53), fontSize: R.sp(context, 12), fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: R.sp(context, 11),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: R.isSmall(context) ? 8 : 12),
                            Text('Đơn hàng: #$shortOrderId', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14), color: const Color(0xFF0F2E53))),
                            const SizedBox(height: 6),
                            Text('Thanh toán: $paymentMethodText', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text('Địa chỉ: $address', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.black87)),
                            SizedBox(height: R.isSmall(context) ? 8 : 12),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 8),
                            if (invoiceItems.isNotEmpty)
                              ...(invoiceItems.map((p) {
                                final refId = p['refId']?.toString();
                                final quantity = p['quantity'] ?? 1;
                                final price = p['price'] ?? 0;
                                final productName = p['name'] ?? 'Sản phẩm';
                                final imgSize = R.isSmall(context) ? 42.0 : 48.0;

                                String? productImg;
                                if (refId != null && _productCache.containsKey(refId)) {
                                  final pData = _productCache[refId];
                                  if (pData['images'] is List && pData['images'].isNotEmpty) {
                                    final firstImg = pData['images'][0];
                                    if (firstImg is String) {
                                      productImg = firstImg;
                                    } else if (firstImg is Map && firstImg['url'] != null) {
                                      productImg = firstImg['url'].toString();
                                    }
                                  } else if (pData['image'] is String) {
                                    productImg = pData['image'];
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: (productImg != null && productImg.toString().startsWith('http'))
                                          ? Image.network(
                                              productImg, 
                                              width: imgSize, 
                                              height: imgSize, 
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Container(width: imgSize, height: imgSize, color: Colors.grey[200], child: const Icon(Icons.inventory, color: Colors.grey, size: 24)),
                                            )
                                          : Container(
                                              width: imgSize, 
                                              height: imgSize, 
                                              color: Colors.grey[200], 
                                              child: const Icon(Icons.inventory, color: Colors.grey, size: 24),
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productName,
                                              style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.w600, color: const Color(0xFF0F2E53)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Số lượng: $quantity',
                                              style: TextStyle(fontSize: R.sp(context, 11), color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(price * quantity),
                                        style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList())
                            else
                              Text('Chưa có chi tiết sản phẩm', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: R.sp(context, 12))),
                            const SizedBox(height: 4),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Số tiền: ${formatCurrency(total)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 15), color: const Color(0xFFF07E2B))),
                                Row(
                                  children: [
                                    if (status == 'pending' && rawPaymentMethod == 'bank')
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: SizedBox(
                                          height: 30,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              if (!mounted) return;
                                              showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                                              try {
                                                final invoiceIdObj = invoice['_id'] ?? invoice['id'];
                                                final invoiceId = invoiceIdObj?.toString() ?? '';
                                                final res = await InvoiceService().initSepayCheckout(widget.user['token'], invoiceId);
                                                if (!mounted) return;
                                                Navigator.pop(context); // close loading
                                                
                                                final resData = (res['data'] is Map) ? res['data'] : {};
                                                String? paymentUrl = res['checkoutPageUrl'] ?? res['url'] ?? resData['checkoutPageUrl'] ?? resData['url'];
                                                
                                                if (paymentUrl != null && paymentUrl.isNotEmpty) {
                                                   final result = await Navigator.push(
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
                                                   if (result == true && mounted) {
                                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giao dịch đã kết thúc, đang tải lại trạng thái đơn hàng...')));
                                                     setState(() => _isLoading = true);
                                                     _fetchInvoices();
                                                   }
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy link thanh toán (checkoutPageUrl)')));
                                                }
                                              } catch (e) {
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải thanh toán: ${e.toString().replaceAll('Exception: ', '')}')));
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F2E53),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            child: Text('Thanh toán', style: TextStyle(fontSize: R.sp(context, 11))),
                                          ),
                                        ),
                                      ),

                                    if (status == 'pending')
                                      SizedBox(
                                        height: 30,
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Xác nhận hủy'),
                                                content: const Text('Bạn có chắc chắn muốn hủy đơn hàng này không?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Có, hủy', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              if (!mounted) return;
                                              try {
                                                showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                                                final invoiceId = invoice['_id'] ?? invoice['id'];
                                                await InvoiceService().cancelInvoice(widget.user['token'], invoiceId);
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hủy đơn hàng thành công')));
                                                setState(() => _isLoading = true);
                                                _fetchInvoices();
                                              } catch (e) {
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                                              }
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          child: Text('Hủy đơn', style: TextStyle(fontSize: R.sp(context, 11))),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
