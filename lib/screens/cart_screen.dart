import 'package:flutter/material.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/screens/store_screen.dart';
import 'package:pet_care/screens/checkout_screen.dart';

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
    
    // Optimistic UI update
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
        // Revert optimistic update
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
          title: const Text('Xác nhận', style: TextStyle(color: Color(0xFF0F2E53), fontWeight: FontWeight.bold)),
          content: const Text('Bạn có chắc chắn muốn xóa sản phẩm này khỏi giỏ hàng?'),
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
        title: const Text('Giỏ hàng', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
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
                      const Text('Giỏ hàng đang trống.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => StoreScreen(user: widget.user)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2E53),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ĐI ĐẾN CỬA HÀNG', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
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
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
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
                                      ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                                      : Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name'] ?? 'Sản phẩm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2E53)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(formatCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF07E2B), fontSize: 14)),
                                          Row(
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
                                                child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                              const SizedBox(width: 8),
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
                      padding: const EdgeInsets.all(20),
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
                                  const Text('Tất cả', style: TextStyle(fontSize: 16, color: Color(0xFF0F2E53))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Tổng thanh toán:', style: TextStyle(fontSize: 14, color: Color(0xFF0F2E53))),
                                  Text(formatCurrency(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF07E2B))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
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
                              child: const Text('TIẾN HÀNH THANH TOÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
