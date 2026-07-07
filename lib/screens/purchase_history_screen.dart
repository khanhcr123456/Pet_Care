import 'package:flutter/material.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/services/product_service.dart';

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
      final invoices = await InvoiceService().getInvoices(widget.user['token']);

      // Show invoices immediately — name is already in items[].name
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }

      // Fetch product images in background (non-blocking)
      _fetchProductImages(invoices);
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
      final items = invoice['items'] ?? invoice['products'] ?? [];
      if (items is List) {
        for (final p in items) {
          final refId = p['refId']?.toString();
          if (refId != null && refId.isNotEmpty && !_productCache.containsKey(refId)) {
            productIds.add(refId);
          }
        }
      }
    }

    if (productIds.isEmpty) return;

    // Fetch all products in parallel
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Lịch sử mua hàng', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
          : _invoices.isEmpty
              ? const Center(child: Text('Chưa có đơn hàng nào', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    final status = invoice['status']?.toString().toLowerCase() ?? 'pending';
                    final date = invoice['createdAt'] != null 
                        ? DateTime.tryParse(invoice['createdAt'])?.toLocal().toString().split('.')[0] ?? ''
                        : '';
                        
                    Color statusColor = Colors.orange;
                    String statusText = 'Chờ xử lý';
                    if (status == 'completed' || status == 'success') {
                      statusColor = Colors.green;
                      statusText = 'Hoàn thành';
                    } else if (status == 'cancelled') {
                      statusColor = Colors.red;
                      statusText = 'Đã hủy';
                    }

                    final address = invoice['address'] ?? 'Chưa cập nhật';
                    final orderId = invoice['_id'] ?? invoice['id'] ?? '';
                    final shortOrderId = orderId.toString().length > 8 ? orderId.toString().substring(0, 8).toUpperCase() : orderId.toString().toUpperCase();
                    
                    final total = invoice['total'] ?? invoice['totalAmount'] ?? 0;
                    final invoiceItems = (invoice['items'] ?? invoice['products'] ?? []) as List;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ngày & giờ: $date', style: const TextStyle(color: Color(0xFF0F2E53), fontSize: 13, fontWeight: FontWeight.w600)),
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Đơn hàng: #$shortOrderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2E53))),
                            const SizedBox(height: 6),
                            Text('Địa chỉ: $address', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 8),
                            if (invoiceItems.isNotEmpty)
                              ...(invoiceItems.map((p) {
                                // API returns: refId, name, price, quantity directly in item
                                final refId = p['refId']?.toString();
                                final quantity = p['quantity'] ?? 1;
                                final price = p['price'] ?? 0;
                                final productName = p['name'] ?? 'Sản phẩm';

                                // Get image from productCache via refId
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
                                              width: 48, 
                                              height: 48, 
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Container(width: 48, height: 48, color: Colors.grey[200], child: const Icon(Icons.inventory, color: Colors.grey, size: 24)),
                                            )
                                          : Container(
                                              width: 48, 
                                              height: 48, 
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
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F2E53)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Số lượng: $quantity',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(price * quantity),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList())
                            else
                              const Text('Chưa có chi tiết sản phẩm', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Số tiền: ${formatCurrency(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF07E2B))),
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
                                            Navigator.pop(context); // close loading
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hủy đơn hàng thành công')));
                                            setState(() => _isLoading = true);
                                            _fetchInvoices();
                                          } catch (e) {
                                            if (!mounted) return;
                                            Navigator.pop(context); // close loading
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
                                      child: const Text('Hủy đơn', style: TextStyle(fontSize: 12)),
                                    ),
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
