import 'package:flutter/material.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/screens/checkout_screen.dart';
import 'package:pet_care/screens/store_screen.dart';
import 'package:pet_care/utils/responsive.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ProductService _productService = ProductService();
  List<dynamic>? _cartItems;
  bool _isLoading = true;
  final Set<String> _selectedItems = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    try {
      final items = await _productService.getCart(widget.user['token']);
      if (mounted) {
        setState(() {
          _cartItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tải giỏ hàng: $e')));
      }
    }
  }

  Future<void> _updateQuantity(String productId, int newQuantity) async {
    if (newQuantity < 1) return;
    
    int oldQuantity = 1;
    final index = _cartItems?.indexWhere((item) => item['product']?['_id'] == productId);
    if (index != null && index >= 0) {
      oldQuantity = _cartItems![index]['quantity'];
      setState(() {
        _cartItems![index]['quantity'] = newQuantity;
      });
    }

    try {
      await _productService.updateCartQuantity(widget.user['token'], productId, newQuantity);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $e')));
        if (index != null && index >= 0) {
          setState(() {
            _cartItems![index]['quantity'] = oldQuantity;
          });
        }
      }
    }
  }

  Future<void> _confirmRemoveItem(String productId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận', style: TextStyle(color: const Color(0xFF0F2E53), fontWeight: FontWeight.bold, fontSize: R.sp(context, 16))),
          content: Text('Bạn có chắc chắn muốn xóa sản phẩm này khỏi giỏ hàng?', style: TextStyle(fontSize: R.sp(context, 13))),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _removeItem(productId);
    }
  }

  Future<void> _removeItem(String productId) async {
    try {
      await _productService.removeFromCart(widget.user['token'], productId);
      setState(() {
        _selectedItems.remove(productId);
      });
      _fetchCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa sản phẩm khỏi giỏ.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
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
    final items = _cartItems ?? [];
    final imgSize = R.isSmall(context) ? 70.0 : 80.0;
    num total = 0;
    
    final selectedCartItems = items.where((item) {
      final productId = item['product']?['_id'] as String?;
      return productId != null && _selectedItems.contains(productId);
    }).toList();

    for (var item in selectedCartItems) {
      final product = item['product'] ?? {};
      final price = product['price'] ?? 0;
      final quantity = item['quantity'] ?? 1;
      total += price * quantity;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(
          'Giỏ hàng',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Giỏ hàng đang trống.', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 15))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Quay về màn hình gốc (Landing) để xóa Store cũ (nếu có),
                          // Sau đó mới Push trang Store mới lên.
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StoreScreen(user: widget.user)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2E53),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: R.isSmall(context) ? 18 : 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('ĐI ĐẾN CỬA HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(R.hPad(context)),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final product = item['product'] ?? {};
                          final images = product['images'] as List<dynamic>?;
                          final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url'] : null;
                          final quantity = item['quantity'] ?? 1;
                          final price = product['price'] ?? 0;
                          final productId = product['_id'] as String?;

                          return Container(
                            margin: EdgeInsets.only(bottom: R.isSmall(context) ? 12 : 16),
                            padding: EdgeInsets.all(R.isSmall(context) ? 10 : 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: productId != null && _selectedItems.contains(productId),
                                  onChanged: (bool? value) {
                                    if (productId != null) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItems.add(productId);
                                        } else {
                                          _selectedItems.remove(productId);
                                        }
                                        _selectAll = _selectedItems.length == items.length && items.isNotEmpty;
                                      });
                                    }
                                  },
                                  activeColor: const Color(0xFFF07E2B),
                                ),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product['name'] ?? 'Sản phẩm',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14), color: const Color(0xFF0F2E53)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              if (productId != null) _confirmRemoveItem(productId);
                                            },
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              formatCurrency(price),
                                              style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFF07E2B), fontSize: R.sp(context, 13)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  if (productId != null) _updateQuantity(productId, quantity - 1);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                                  child: const Icon(Icons.remove, size: 16),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Text('$quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13))),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  if (productId != null) _updateQuantity(productId, quantity + 1);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                                  child: const Icon(Icons.add, size: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(R.hPad(context) + 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _selectAll,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _selectAll = value ?? false;
                                        if (_selectAll) {
                                          _selectedItems.addAll(items
                                              .map((item) => item['product']?['_id'] as String?)
                                              .where((id) => id != null)
                                              .cast<String>());
                                        } else {
                                          _selectedItems.clear();
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFFF07E2B),
                                  ),
                                  Text('Tất cả', style: TextStyle(fontSize: R.sp(context, 14), color: const Color(0xFF0F2E53))),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Tổng thanh toán:', style: TextStyle(fontSize: R.sp(context, 12), color: const Color(0xFF0F2E53)), maxLines: 1),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(formatCurrency(total), style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFFF07E2B))),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: R.isSmall(context) ? 46 : 50,
                            child: ElevatedButton(
                              onPressed: _selectedItems.isEmpty ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutScreen(
                                      user: widget.user,
                                      selectedItems: selectedCartItems,
                                      totalAmount: total,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F2E53),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('TIẾN HÀNH THANH TOÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
