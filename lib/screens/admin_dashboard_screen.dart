import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/screens/profile_screen.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/screens/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF0F2E53)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFFF07E2B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: 'Dịch vụ'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Sản phẩm'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn hàng'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return AdminServicesTab(user: widget.user);
      case 1:
        return AdminProductsTab(user: widget.user);
      case 2:
        return AdminOrdersTab(user: widget.user);
      default:
        return const Center(child: Text('Unknown screen'));
    }
  }
}

// --------------------------------------------------------------------------
// QUẢN LÝ DỊCH VỤ
// --------------------------------------------------------------------------
class AdminServicesTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminServicesTab({super.key, required this.user});

  @override
  State<AdminServicesTab> createState() => _AdminServicesTabState();
}

class _AdminServicesTabState extends State<AdminServicesTab> {
  bool _isLoading = true;
  List<dynamic> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final data = await PetService().getServices(limit: 100);
      if (!mounted) return;
      setState(() {
        _services = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(Map<String, dynamic> svc) async {
    final id = svc['_id'] ?? svc['id'];
    if (id == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa dịch vụ "${svc['name']}" vĩnh viễn không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await PetService().deleteService(widget.user['token'], id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa dịch vụ thành công')));
                  setState(() => _isLoading = true);
                  _fetchServices();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    
    String selectedType = 'consultation';
    final List<String> types = ['grooming', 'vaccination', 'boarding', 'consultation', 'other'];
    final Map<String, String> typeTranslations = {
      'grooming': 'Làm đẹp',
      'vaccination': 'Tiêm phòng',
      'boarding': 'Trông giữ',
      'consultation': 'Khám bệnh',
      'other': 'Khác'
    };

    File? selectedImage;
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm dịch vụ mới'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên dịch vụ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá dịch vụ (VND)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Loại dịch vụ', border: OutlineInputBorder()),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(typeTranslations[t] ?? t))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(selectedImage!, height: 300, width: double.infinity, fit: BoxFit.contain),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedImage != null ? 'Đã chọn ảnh' : 'Chưa có ảnh'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setDialogState(() {
                                selectedImage = File(pickedFile.path);
                              });
                            }
                          },
                          child: const Text('Chọn ảnh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (nameController.text.isEmpty || priceController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên và giá')));
                            return;
                          }
                          setDialogState(() => isAdding = true);
                          try {
                            final Map<String, dynamic> addData = {
                              'name': nameController.text,
                              'description': descController.text,
                              'price': priceController.text,
                              'type': selectedType,
                            };
                            
                            await PetService().addService(
                              widget.user['token'], 
                              addData,
                              imageFile: selectedImage,
                            );
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thành công')));
                              setState(() => _isLoading = true);
                              _fetchServices();
                            }
                          } catch (e) {
                            setDialogState(() => isAdding = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF07E2B)),
                  child: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Thêm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showEditServiceDialog(Map<String, dynamic> svc) {
    final TextEditingController nameController = TextEditingController(text: svc['name'] ?? '');
    final TextEditingController descController = TextEditingController(text: svc['description'] ?? '');
    final TextEditingController priceController = TextEditingController(text: svc['price']?.toString() ?? '0');
    
    // Set cursor to the end
    nameController.selection = TextSelection.collapsed(offset: nameController.text.length);
    descController.selection = TextSelection.collapsed(offset: descController.text.length);
    priceController.selection = TextSelection.collapsed(offset: priceController.text.length);
    
    String selectedType = svc['type'] ?? 'consultation';
    final List<String> types = ['grooming', 'vaccination', 'boarding', 'consultation', 'other'];
    if (!types.contains(selectedType)) {
      selectedType = 'other';
    }

    final Map<String, String> typeTranslations = {
      'grooming': 'Làm đẹp',
      'vaccination': 'Tiêm phòng',
      'boarding': 'Trông giữ',
      'consultation': 'Khám bệnh',
      'other': 'Khác'
    };

    File? selectedImage;
    final images = svc['images'] as List<dynamic>?;
    final String? existingImageUrl = (images != null && images.isNotEmpty) ? images[0].toString() : null;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật dịch vụ'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên dịch vụ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá dịch vụ (VND)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Loại dịch vụ', border: OutlineInputBorder()),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(typeTranslations[t] ?? t))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(selectedImage!, height: 300, width: double.infinity, fit: BoxFit.contain),
                        ),
                      )
                    else if (existingImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(existingImageUrl, height: 300, width: double.infinity, fit: BoxFit.contain, errorBuilder: (_,__,___) => const SizedBox()),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedImage != null ? 'Đã chọn ảnh mới' : (existingImageUrl != null ? 'Đang dùng ảnh hiện tại' : 'Chưa có ảnh')),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setDialogState(() {
                                selectedImage = File(pickedFile.path);
                              });
                            }
                          },
                          child: const Text('Chọn ảnh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setDialogState(() => isUpdating = true);
                          try {
                            final Map<String, dynamic> updateData = {
                              'name': nameController.text,
                              'description': descController.text,
                              'price': priceController.text,
                              'type': selectedType,
                            };
                            
                            await PetService().updateService(
                              widget.user['token'], 
                              svc['_id'] ?? svc['id'], 
                              updateData,
                              imageFile: selectedImage,
                            );
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
                              setState(() => _isLoading = true);
                              _fetchServices();
                            }
                          } catch (e) {
                            setDialogState(() => isUpdating = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF07E2B)),
                  child: isUpdating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddServiceDialog,
        backgroundColor: const Color(0xFFF07E2B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final svc = _services[index];
        final price = svc['price']?.toString() ?? '0';
        final description = svc['description'] ?? 'Không có mô tả';
        final isActive = svc['isActive'] == true || svc['status'] == 'active';
        final images = svc['images'] as List<dynamic>?;
        final imageUrl = (images != null && images.isNotEmpty) ? images[0].toString() : null;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: const Color(0xFF0F2E53), child: const Icon(Icons.medical_services, color: Colors.white)))
                      : Container(width: 80, height: 80, color: const Color(0xFF0F2E53), child: const Icon(Icons.medical_services, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(svc['name'] ?? 'Dịch vụ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Giá: $price VND', style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                        'Mô tả: $description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trạng thái: ${isActive ? 'Hoạt động' : 'Tạm ngưng'}',
                        style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditServiceDialog(svc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteService(svc),
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

// --------------------------------------------------------------------------
// QUẢN LÝ SẢN PHẨM
// --------------------------------------------------------------------------
class AdminProductsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminProductsTab({super.key, required this.user});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  bool _isLoading = true;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await ProductService().getProducts(limit: 100);
      if (!mounted) return;
      setState(() {
        _products = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAddProductDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    
    String selectedCategory = 'food';
    final List<String> categories = ['food', 'toy', 'accessory', 'medicine', 'other'];
    final Map<String, String> categoryTranslations = {
      'food': 'Thức ăn',
      'toy': 'Đồ chơi',
      'accessory': 'Phụ kiện',
      'medicine': 'Thuốc',
      'other': 'Khác'
    };

    File? selectedImage;
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm sản phẩm mới'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá sản phẩm (VND)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng kho', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                      items: categories.map((t) => DropdownMenuItem(value: t, child: Text(categoryTranslations[t] ?? t))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(selectedImage!, height: 300, width: double.infinity, fit: BoxFit.contain),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedImage != null ? 'Đã chọn ảnh' : 'Chưa có ảnh'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setDialogState(() {
                                selectedImage = File(pickedFile.path);
                              });
                            }
                          },
                          child: const Text('Chọn ảnh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (nameController.text.isEmpty || priceController.text.isEmpty || stockController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên, giá và số lượng')));
                            return;
                          }
                          setDialogState(() => isAdding = true);
                          try {
                            final int stockQuantity = int.tryParse(stockController.text) ?? 0;
                            final Map<String, dynamic> addData = {
                              'name': nameController.text,
                              'description': descController.text,
                              'price': priceController.text,
                              'category': selectedCategory,
                              'petTypes': ['dog', 'cat', 'bird'],
                              'stock': {'quantity': stockQuantity, 'status': stockQuantity > 0 ? 'in_stock' : 'out_of_stock'},
                            };
                            
                            await ProductService().addProduct(
                              widget.user['token'], 
                              addData,
                              imageFile: selectedImage,
                            );
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thành công')));
                              setState(() => _isLoading = true);
                              _fetchProducts();
                            }
                          } catch (e) {
                            setDialogState(() => isAdding = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF07E2B)),
                  child: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Thêm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteProduct(Map<String, dynamic> prod) async {
    final id = prod['_id'] ?? prod['id'];
    if (id == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa sản phẩm "${prod['name']}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ProductService().deleteProduct(widget.user['token'], id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa sản phẩm thành công')));
                  setState(() => _isLoading = true);
                  _fetchProducts();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> prod) {
    final TextEditingController nameController = TextEditingController(text: prod['name'] ?? '');
    final TextEditingController descController = TextEditingController(text: prod['description'] ?? '');
    final TextEditingController priceController = TextEditingController(text: prod['price']?.toString() ?? '0');
    
    int stockQty = 0;
    if (prod['stock'] is Map) {
      stockQty = prod['stock']['quantity'] ?? 0;
    } else if (prod['stock'] is num) {
      stockQty = prod['stock'].toInt();
    }
    final TextEditingController stockController = TextEditingController(text: stockQty.toString());
    
    String selectedCategory = prod['category'] ?? 'food';
    final List<String> categories = ['food', 'toy', 'accessory', 'medicine', 'other'];
    if (!categories.contains(selectedCategory)) {
      selectedCategory = 'other';
    }
    
    final Map<String, String> categoryTranslations = {
      'food': 'Thức ăn',
      'toy': 'Đồ chơi',
      'accessory': 'Phụ kiện',
      'medicine': 'Thuốc',
      'other': 'Khác'
    };

    File? selectedImage;
    
    String? existingImageUrl;
    final images = prod['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      final firstImage = images[0];
      if (firstImage is Map) {
        existingImageUrl = firstImage['url']?.toString();
      } else {
        existingImageUrl = firstImage.toString();
      }
    }
    
    bool isUpdating = false;
    final id = prod['_id'] ?? prod['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật sản phẩm'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá sản phẩm (VND)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng kho', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                      items: categories.map((t) => DropdownMenuItem(value: t, child: Text(categoryTranslations[t] ?? t))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(selectedImage!, height: 300, width: double.infinity, fit: BoxFit.contain),
                        ),
                      )
                    else if (existingImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(existingImageUrl!, height: 300, width: double.infinity, fit: BoxFit.contain),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedImage != null ? 'Đã chọn ảnh mới' : (existingImageUrl != null ? 'Giữ ảnh cũ' : 'Chưa có ảnh')),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setDialogState(() {
                                selectedImage = File(pickedFile.path);
                              });
                            }
                          },
                          child: const Text('Chọn ảnh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          if (nameController.text.isEmpty || priceController.text.isEmpty || stockController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên, giá và số lượng')));
                            return;
                          }
                          setDialogState(() => isUpdating = true);
                          try {
                            final int stockQuantity = int.tryParse(stockController.text) ?? 0;
                            final Map<String, dynamic> updateData = {
                              'name': nameController.text,
                              'description': descController.text,
                              'price': priceController.text,
                              'category': selectedCategory,
                              'petTypes': ['dog', 'cat', 'bird'],
                              'stock': {'quantity': stockQuantity, 'status': stockQuantity > 0 ? 'in_stock' : 'out_of_stock'},
                            };
                            
                            await ProductService().updateProduct(
                              widget.user['token'], 
                              id,
                              updateData,
                              imageFile: selectedImage,
                            );
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
                              setState(() => _isLoading = true);
                              _fetchProducts();
                            }
                          } catch (e) {
                            setDialogState(() => isUpdating = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF07E2B)),
                  child: isUpdating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: const Color(0xFFF07E2B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final prod = _products[index];
        final price = prod['price']?.toString() ?? '0';
        
        String? imageUrl;
        final images = prod['images'] as List<dynamic>?;
        if (images != null && images.isNotEmpty) {
          final firstImage = images[0];
          if (firstImage is Map) {
            imageUrl = firstImage['url']?.toString();
          } else {
            imageUrl = firstImage.toString();
          }
        }
        
        int stockQty = 0;
        final stock = prod['stock'];
        if (stock is Map) {
          stockQty = stock['quantity'] ?? 0;
        } else if (stock is num) {
          stockQty = stock.toInt();
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null 
                    ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.contain, errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.inventory_2, size: 40)))
                    : Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.inventory_2, size: 40)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prod['name'] ?? 'Sản phẩm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Giá: $price VND\nKho: $stockQty'),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditProductDialog(prod),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProduct(prod),
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

// --------------------------------------------------------------------------
// QUẢN LÝ ĐƠN HÀNG
// --------------------------------------------------------------------------
class AdminOrdersTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminOrdersTab({super.key, required this.user});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    try {
      final data = await InvoiceService().getInvoices(widget.user['token'], limit: 100);
      if (!mounted) return;
      
      // Chỉ lấy các đơn hàng mà bên trong mảng items có chứa sản phẩm (type: 'product')
      final productInvoices = data.where((inv) {
        final items = (inv['items'] ?? inv['products'] ?? []) as List;
        return items.any((item) => item['type']?.toString().toLowerCase() == 'product');
      }).toList();

      setState(() {
        _invoices = productInvoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String id, String status) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      await InvoiceService().updateInvoiceStatus(widget.user['token'], id, status);
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật trạng thái thành công')));
        setState(() => _isLoading = true);
        _fetchInvoices();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = inv['total']?.toString() ?? inv['totalAmount']?.toString() ?? '0';
        final rawStatus = inv['orderStatus'] ?? inv['status'] ?? 'pending';
        
        String status = rawStatus;
        switch (rawStatus.toString().toLowerCase()) {
          case 'pending': status = 'Chờ xác nhận'; break;
          case 'awaiting_confirmation': status = 'Chờ xác nhận'; break;
          case 'confirmed': status = 'Đã xác nhận'; break;
          case 'preparing': status = 'Đang chuẩn bị'; break;
          case 'shipping': status = 'Đang giao'; break;
          case 'delivered': status = 'Đã giao'; break;
          case 'completed': status = 'Hoàn thành'; break;
          case 'cancelled': status = 'Đã hủy'; break;
          case 'return_requested': status = 'Yêu cầu trả hàng'; break;
          case 'returned': status = 'Đã trả hàng'; break;
        }

        final String rawStatusLower = rawStatus.toString().toLowerCase();
        
        String? nextStepText;
        String? nextStepStatus;
        Color nextStepColor = const Color(0xFF4CAF50);
        
        switch (rawStatusLower) {
          case 'pending':
          case 'awaiting_confirmation':
            nextStepText = 'Xác nhận đơn';
            nextStepStatus = 'confirmed';
            nextStepColor = Colors.blue;
            break;
          case 'confirmed':
            nextStepText = 'Chuẩn bị hàng';
            nextStepStatus = 'preparing';
            nextStepColor = Colors.orange;
            break;
          case 'processing':
          case 'preparing':
            nextStepText = 'Giao hàng';
            nextStepStatus = 'shipping';
            nextStepColor = Colors.teal;
            break;
          case 'shipping':
            nextStepText = 'Đã giao';
            nextStepStatus = 'delivered';
            nextStepColor = Colors.indigo;
            break;
          case 'delivered':
            nextStepText = 'Hoàn thành';
            nextStepStatus = 'completed';
            nextStepColor = Colors.green;
            break;
        }
        
        bool canCancel = !['completed', 'cancelled', 'returned'].contains(rawStatusLower);

        final items = (inv['items'] ?? inv['products'] ?? []) as List;
        
        final userObj = inv['user'] is Map ? inv['user'] : {};
        final customerName = inv['receiverName'] ?? inv['customerName'] ?? inv['customer'] ?? inv['name'] ?? inv['fullName'] ?? userObj['name'] ?? userObj['fullName'] ?? userObj['username'] ?? 'Không rõ';
        final customerPhone = inv['phone'] ?? inv['customerPhone'] ?? userObj['phone'] ?? 'Không rõ';
        
        String address = 'Không rõ';
        final sa = inv['address'] ?? inv['shippingAddress'];
        if (sa is Map) {
          address = [sa['street'] ?? sa['address'], sa['ward'], sa['district'], sa['city']]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .join(', ');
        } else if (sa != null && sa.toString().trim().isNotEmpty) {
          address = sa.toString().trim();
        }
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFFF8F1E7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFF07E2B), child: Icon(Icons.receipt_long, color: Colors.white)),
            title: Text('Đơn hàng: ${inv['_id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333), fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Tổng: $total VND', style: const TextStyle(color: Color(0xFF555555), fontSize: 13)),
                const SizedBox(height: 2),
                Text('Trạng thái: $status', style: const TextStyle(color: Color(0xFF555555), fontSize: 13)),
              ],
            ),
            iconColor: const Color(0xFF555555),
            collapsedIconColor: const Color(0xFF555555),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin giao hàng:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2E53), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Tên: $customerName', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                    const SizedBox(height: 4),
                    Text('SĐT: $customerPhone', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                    const SizedBox(height: 4),
                    Text('Địa chỉ: $address', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                    const Divider(color: Colors.black12, thickness: 1, height: 24),
                    const Text('Chi tiết sản phẩm:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2E53), fontSize: 14)),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      final name = item['name'] ?? 'Sản phẩm';
                      final qty = item['quantity']?.toString() ?? '1';
                      final price = item['price']?.toString() ?? '0';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('- $name', style: const TextStyle(fontSize: 14, color: Color(0xFF333333)))),
                            Text('x$qty', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(width: 16),
                            Text('$price VND', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(color: Colors.black12, thickness: 1, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thành tiền:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2E53))),
                        Text('$total VND', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF07E2B))),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (nextStepText != null) ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nextStepColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (nextStepStatus != null) {
                              _updateOrderStatus(inv['_id'], nextStepStatus!);
                            }
                          },
                          child: Text(nextStepText, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (canCancel) const SizedBox(width: 16),
                    ],
                    if (canCancel)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _updateOrderStatus(inv['_id'], 'cancelled');
                          },
                          child: const Text('Hủy', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
