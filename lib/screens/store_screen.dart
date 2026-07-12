import 'package:flutter/material.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/screens/cart_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

class StoreScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const StoreScreen({super.key, this.user});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with TickerProviderStateMixin {
  final ProductService _productService = ProductService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  final Set<String> _addingToCart = {};
  
  final GlobalKey _cartKey = GlobalKey();
  final Map<String, GlobalKey> _productKeys = {};
  int _cartCount = 0;
  final Set<String> _cartProductIds = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchCartCount();
  }

  Future<void> _fetchCartCount() async {
    if (widget.user != null && widget.user!['token'] != null) {
      try {
        final items = await _productService.getCart(widget.user!['token']);
        if (mounted) {
          setState(() {
            _cartProductIds.clear();
            for (var item in items) {
              final pid = item['product']?['_id'];
              if (pid is String) {
                _cartProductIds.add(pid);
              }
            }
            _cartCount = _cartProductIds.length;
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await _productService.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách sản phẩm.')),
        );
      }
    }
  }

  void _runAddToCartAnimation(GlobalKey imageKey, String imageUrl, String productId) {
    final RenderBox? renderBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? cartRenderBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || cartRenderBox == null) return;

    final startPosition = renderBox.localToGlobal(Offset.zero);
    final endPosition = cartRenderBox.localToGlobal(Offset(cartRenderBox.size.width / 2, cartRenderBox.size.height / 2));

    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          onEnd: () {
            overlayEntry.remove();
            if (!_cartProductIds.contains(productId)) {
              setState(() {
                _cartProductIds.add(productId);
                _cartCount = _cartProductIds.length;
              });
            }
          },
          builder: (context, double t, child) {
            final dx = startPosition.dx + (endPosition.dx - startPosition.dx) * t;
            // Arc path using parabola
            final dy = startPosition.dy + (endPosition.dy - startPosition.dy) * t + (200 * t * (t - 1));
            
            return Positioned(
              left: dx,
              top: dy,
              child: Opacity(
                opacity: 1.0 - (t * 0.5),
                child: Transform.scale(
                  scale: 1.0 - (t * 0.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                        : Container(width: 60, height: 60, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Future<void> _addToCart(String productId, int quantity, String imageUrl) async {
    if (widget.user == null || widget.user!['token'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để mua hàng!')));
      return;
    }

    setState(() => _addingToCart.add(productId));

    try {
      await _productService.addToCart(widget.user!['token'], productId, quantity);
      if (mounted) {
        final key = _productKeys[productId];
        if (key != null) {
          _runAddToCartAnimation(key, imageUrl, productId);
        } else {
          if (!_cartProductIds.contains(productId)) {
            setState(() {
              _cartProductIds.add(productId);
              _cartCount = _cartProductIds.length;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _addingToCart.remove(productId));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Cửa Hàng PetCare', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                key: _cartKey,
                onPressed: () async {
                  if (widget.user == null || widget.user!['token'] == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để xem giỏ hàng!')));
                    return;
                  }
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(user: widget.user!)));
                  _fetchCartCount(); // Refresh count when returning
                },
                icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0F2E53)),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? GridView.builder(
              padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: R.gridCount(context),
                childAspectRatio: R.gridAspectRatio(context),
                crossAxisSpacing: R.isSmall(context) ? 8 : 14,
                mainAxisSpacing: R.isSmall(context) ? 8 : 14,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
          : _products.isEmpty
              ? const Center(child: Text('Không có sản phẩm nào.', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: R.gridCount(context),
                    childAspectRatio: R.gridAspectRatio(context),
                    crossAxisSpacing: R.isSmall(context) ? 8 : 14,
                    mainAxisSpacing: R.isSmall(context) ? 8 : 14,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final images = product['images'] as List<dynamic>?;
                    final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url'] : null;
                    final discount = product['discount']?['active'] == true ? product['discount']['percentage'] : 0;
                    final key = _productKeys.putIfAbsent(product['_id'], () => GlobalKey());
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          Expanded(
                            flex: 4,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  key: key,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: imageUrl != null
                                      ? Image.network(
                                          imageUrl,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                                ),
                                if (discount > 0)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-$discount%',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Info
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? 'Sản phẩm',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53), fontSize: R.sp(context, 14)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.star, color: Colors.amber, size: R.sp(context, 14)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${product['rating']?['average'] ?? 0.0}',
                                            style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            ' (${product['rating']?['count'] ?? 0})',
                                            style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatCurrency(product['price'] ?? 0),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFF07E2B), fontSize: R.sp(context, 15)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        height: R.isSmall(context) ? 32 : R.sp(context, 36),
                                        child: ElevatedButton(
                                          onPressed: _addingToCart.contains(product['_id']) 
                                              ? null 
                                              : () => _addToCart(product['_id'], 1, imageUrl ?? ''),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2E53),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: _addingToCart.contains(product['_id']) 
                                              ? SizedBox(width: R.sp(context, 14), height: R.sp(context, 14), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text('Thêm vào giỏ', style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
