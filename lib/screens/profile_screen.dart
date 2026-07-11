import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';
import 'package:pet_care/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Function(Map<String, dynamic>)? onUserUpdated;

  const ProfileScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isUploadingAvatar = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user != null) {
      _nameController.text = _user!['name'] ?? _user!['fullName'] ?? '';
      _phoneController.text = _user!['phone'] ?? '';
      _addressController.text = _user!['address'] ?? '';
      _fetchUserProfile();
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_user == null || _user!['token'] == null) return;
    try {
      final authService = AuthService();
      final freshData = await authService.getMe(_user!['token']);
      if (mounted) {
        // We do not append ?v=timestamp here to prevent the avatar from flickering/reloading
        // when the user opens the profile screen.

        setState(() {
          _user = {
            ..._user!,
            ...freshData,
          };
          if (!_isEditing) {
            _nameController.text = _user!['name'] ?? _user!['fullName'] ?? '';
            _phoneController.text = _user!['phone'] ?? '';
            _addressController.text = _user!['address'] ?? '';
          }
        });
        widget.onUserUpdated?.call(_user!);
      }
    } catch (e) {
      print('Lỗi tải thông tin user: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarAndUpload() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (_user == null || _user!['token'] == null) return;
      setState(() => _isUploadingAvatar = true);
      
      try {
        final authService = AuthService();
        final updatedData = await authService.updateProfile(
          _user!['token'],
          {
            'name': _user!['name'] ?? _user!['fullName'] ?? '',
            'fullName': _user!['fullName'] ?? _user!['name'] ?? '',
            'phone': _user!['phone'] ?? '',
            'address': _user!['address'] ?? '',
          },
          avatarPath: pickedFile.path,
        );
        
        if (updatedData['avatar'] != null) {
          updatedData['avatar'] = "${updatedData['avatar']}?v=${DateTime.now().millisecondsSinceEpoch}";
        }
        
        setState(() {
          _user = {
            ..._user!,
            ...updatedData,
          };
        });
        widget.onUserUpdated?.call(_user!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      } finally {
        if (mounted) setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null || _user!['token'] == null) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final updatedData = await authService.updateProfile(
        _user!['token'],
        {
          'name': _nameController.text.trim(),
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
        },
      );
      
      setState(() {
        _user = {
          ..._user!,
          ...updatedData,
        };
        _isEditing = false;
      });
      widget.onUserUpdated?.call(_user!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thông tin thành công!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Vui lòng đăng nhập để xem thông tin.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2E53),
                foregroundColor: Colors.white,
              ),
              child: const Text('Đăng nhập ngay'),
            )
          ],
        ),
      );
    }

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                // Avatar Section
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAvatarAndUpload,
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD740), width: 3),
                            image: DecorationImage(
                              image: _getAvatarImage(),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: _isUploadingAvatar
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2E53)))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Color(0xFF0F2E53), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _user!['role'] == 'admin' ? 'Quản Trị Viên' : 'Khách Hàng',
                    style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // Information List
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoItem(icon: Icons.person_outline, title: 'Họ và tên', value: _user!['name'] ?? _user!['fullName'] ?? 'Người Dùng', controller: _nameController, isEditable: _isEditing),
                      const Divider(height: 1),
                      _buildInfoItem(icon: Icons.email_outlined, title: 'Email', value: _user!['email'] ?? 'Chưa cập nhật', isEditable: false),
                      const Divider(height: 1),
                      _buildInfoItem(icon: Icons.phone_outlined, title: 'Số điện thoại', value: _user!['phone'] ?? 'Chưa cập nhật', controller: _phoneController, isEditable: _isEditing, keyboardType: TextInputType.phone),
                      const Divider(height: 1),
                      _buildInfoItem(icon: Icons.location_on_outlined, title: 'Địa chỉ', value: _user!['address'] ?? 'Chưa cập nhật', controller: _addressController, isEditable: _isEditing),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Edit / Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_isEditing) _saveProfile();
                      else setState(() => _isEditing = true);
                    },
                    icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                    label: Text(_isEditing ? 'Lưu Thông Tin' : 'Chỉnh Sửa Thông Tin', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2E53),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                if (_isEditing) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isEditing = false;
                        _nameController.text = _user!['name'] ?? _user!['fullName'] ?? '';
                        _phoneController.text = _user!['phone'] ?? '';
                        _addressController.text = _user!['address'] ?? '';
                      }),
                      child: const Text('Hủy', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    ),
                  ),
                ],

                if (_user!['role']?.toString().toLowerCase() != 'admin' && _user!['role']?.toString().toLowerCase() != 'vet' && _user!['role']?.toString().toLowerCase() != 'doctor') ...[
                  const SizedBox(height: 10),
                  // Purchase History Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseHistoryScreen(user: _user!))),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Lịch Sử Đơn Hàng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF07E2B),
                        side: const BorderSide(color: Color(0xFFF07E2B)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_user?['token'] != null) await AuthService().logout(_user!['token']);
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Đăng Xuất', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),

        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0F2E53),
              ),
            ),
          ),
      ],
    );
  }

  ImageProvider _getAvatarImage() {
    final avatarUrl = _user!['avatar'];
    if (avatarUrl != null && avatarUrl.toString().trim().isNotEmpty && avatarUrl.toString().startsWith('http')) {
      return NetworkImage(avatarUrl);
    }
    final role = _user!['role']?.toString().toLowerCase();
    if (role == 'admin' || role == 'vet' || role == 'doctor') {
      return const AssetImage('assets/images/default_vet.png');
    }
    return const AssetImage('assets/images/hero_pets.png');
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    TextEditingController? controller,
    bool isEditable = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                if (isEditable && controller != null)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(),
                    ),
                  )
                else
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          if (!isEditable)
            const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}
