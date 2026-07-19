import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/screens/profile_screen.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/services/product_service.dart';
import 'package:pet_care/services/invoice_service.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _fetchCurrentUser();
  }

  Future<void> _fetchCurrentUser() async {
    if (_currentUser == null || _currentUser!['token'] == null) return;
    try {
      final userResponse = await AuthService().getMe(_currentUser!['token']);
      if (mounted) {
        setState(() {
          final token = _currentUser!['token'];
          _currentUser = {...?_currentUser, ...userResponse};
          _currentUser!['token'] = token;
        });
      }
    } catch (e) {
      print('Error fetching admin profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ClipOval(
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.grey[200],
                  child: (_currentUser?['avatar'] != null && _currentUser!['avatar'].toString().trim().isNotEmpty && _currentUser!['avatar'].toString().startsWith('http'))
                      ? Image.network(
                          _currentUser!['avatar'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset('assets/images/default_vet.png', fit: BoxFit.cover),
                        )
                      : Image.asset('assets/images/default_vet.png', fit: BoxFit.cover),
                ),
              ),
            ),
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
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
      case 3:
        return ProfileScreen(
          user: _currentUser,
          onUserUpdated: (updatedUser) {
            setState(() {
              _currentUser = updatedUser;
            });
          },
        );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Thêm dịch vụ mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên dịch vụ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 5,
                      minLines: 3,
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
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.contain),
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isAdding ? null : () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
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
                    ),
                  ],
                ),
              ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cập nhật dịch vụ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên dịch vụ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 5,
                      minLines: 3,
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
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.contain),
                        ),
                      )
                    else if (existingImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(existingImageUrl, height: 150, width: double.infinity, fit: BoxFit.contain, errorBuilder: (_,__,___) => const SizedBox()),
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
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
                    ),
                  ],
                ),
              ),
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
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
      padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, color: Colors.grey[200], child: Icon(Icons.medical_services, color: Colors.grey[500], size: R.isSmall(context) ? 25 : 35)))
                          : Container(width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, color: Colors.grey[200], child: Icon(Icons.medical_services, color: Colors.grey[500], size: R.isSmall(context) ? 25 : 35)),
                    ),
                    SizedBox(width: R.isSmall(context) ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(svc['name'] ?? 'Dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: const Color(0xFF0F2E53))),
                          const SizedBox(height: 4),
                          Text('Giá: $price VND', style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Trạng thái: ${isActive ? 'Hoạt động' : 'Tạm ngưng'}',
                            style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: R.sp(context, 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mô tả: $description',
                  style: TextStyle(fontSize: R.sp(context, 13), color: Colors.black87),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                      label: Text('Chỉnh sửa', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.blue)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showEditServiceDialog(svc),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: Text('Xóa', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Thêm sản phẩm mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 5,
                      minLines: 3,
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
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.contain),
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isAdding ? null : () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
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
                    ),
                  ],
                ),
              ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cập nhật sản phẩm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                      maxLines: 5,
                      minLines: 3,
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
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.contain),
                        ),
                      )
                    else if (existingImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(existingImageUrl!, height: 150, width: double.infinity, fit: BoxFit.contain),
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
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
                    ),
                  ],
                ),
              ),
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
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
      padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final prod = _products[index];
        final price = prod['price']?.toString() ?? '0';
        final description = prod['description'] ?? 'Không có mô tả';
        
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null 
                        ? Image.network(imageUrl, width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, color: Colors.grey[200], child: Icon(Icons.inventory_2, size: R.isSmall(context) ? 30 : 40, color: Colors.grey[500])))
                        : Container(width: R.isSmall(context) ? 60 : 80, height: R.isSmall(context) ? 60 : 80, color: Colors.grey[200], child: Icon(Icons.inventory_2, size: R.isSmall(context) ? 30 : 40, color: Colors.grey[500])),
                    ),
                    SizedBox(width: R.isSmall(context) ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod['name'] ?? 'Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: const Color(0xFF0F2E53))),
                          const SizedBox(height: 4),
                          Text('Giá: $price VND', style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Kho: $stockQty',
                            style: TextStyle(color: stockQty > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: R.sp(context, 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mô tả: $description',
                  style: TextStyle(fontSize: R.sp(context, 13), color: Colors.black87),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                      label: Text('Chỉnh sửa', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.blue)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showEditProductDialog(prod),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: Text('Xóa', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
  Map<String, dynamic> _productCache = {};

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    try {
      final results = await Future.wait([
        InvoiceService().getInvoices(widget.user['token'], limit: 100),
        ProductService().getProducts(limit: 100),
      ]);
      final data = results[0] as List<dynamic>;
      final products = results[1] as List<dynamic>;
      
      final cache = <String, dynamic>{};
      for (var p in products) {
        final pid = p['_id'] ?? p['id'];
        if (pid != null) cache[pid.toString()] = p;
      }
      
      if (!mounted) return;
      _productCache = cache;
      
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
        setState(() {
          final index = _invoices.indexWhere((inv) => (inv['_id']?.toString() ?? inv['id']?.toString()) == id);
          if (index != -1) {
            if (_invoices[index] is Map) {
              final updatedInv = Map<String, dynamic>.from(_invoices[index]);
              updatedInv['orderStatus'] = status;
              updatedInv['status'] = status;
              _invoices[index] = updatedInv;
            }
          }
        });
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
      padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
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
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: EdgeInsets.zero,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Đơn hàng: #${(inv['_id']?.toString() ?? inv['id']?.toString() ?? '')}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14), color: const Color(0xFF0F2E53)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: nextStepColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: nextStepColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: nextStepColor, fontWeight: FontWeight.bold, fontSize: R.sp(context, 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                 
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('$total VND', style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
              ),
              iconColor: const Color(0xFF555555),
              collapsedIconColor: const Color(0xFF555555),
              children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thông tin giao hàng:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2E53), fontSize: 14)),
                    SizedBox(height: 8),
                    Text('Tên: $customerName', style: TextStyle(fontSize: R.sp(context, 14), color: Color(0xFF333333))),
                    SizedBox(height: 4),
                    Text('SĐT: $customerPhone', style: TextStyle(fontSize: R.sp(context, 14), color: Color(0xFF333333))),
                    SizedBox(height: 4),
                    Text('Địa chỉ: $address', style: TextStyle(fontSize: R.sp(context, 14), color: Color(0xFF333333))),
                    const Divider(color: Colors.black12, thickness: 1, height: 24),
                    const Text('Chi tiết sản phẩm:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2E53), fontSize: 14)),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      final name = item['name'] ?? 'Sản phẩm';
                      final qty = item['quantity']?.toString() ?? '1';
                      final price = item['price']?.toString() ?? '0';
                      
                      final refId = item['refId']?.toString() ?? item['productId']?.toString();
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
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (productImg != null && productImg.startsWith('http'))
                                  ? Image.network(
                                      productImg,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(width: 48, height: 48, color: Colors.grey[200], child: const Icon(Icons.inventory, color: Colors.grey, size: 20)),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.inventory, color: Colors.grey, size: 20),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontSize: R.sp(context, 14), color: const Color(0xFF333333), fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('Số lượng: $qty', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey[600])),
                                ],
                              )
                            ),
                            const SizedBox(width: 16),
                            Text('$price VND', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(color: Colors.black12, thickness: 1, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Thành tiền:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: Color(0xFF0F2E53))),
                        Text('$total VND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: Color(0xFFF07E2B))),
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
                          child: Text(nextStepText, style: TextStyle(color: Colors.white, fontSize: R.sp(context, 15), fontWeight: FontWeight.bold)),
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
                          child: Text('Hủy', style: TextStyle(color: Colors.white, fontSize: R.sp(context, 15), fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              )
            ],
            ),
          ),
        );
      },
    );
  }
}
