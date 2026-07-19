import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/utils/responsive.dart';

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

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng điền đầy đủ Họ tên, Số điện thoại và Địa chỉ!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final updatedData = await authService.updateProfile(
        _user!['token'],
        {
          'name': name,
          'fullName': name,
          'phone': phone,
          'address': address,
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
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg, 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = R.avatarSize(context);

    if (_user == null) {
      return Center(
        child: Padding(
          padding: R.pagePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: R.iconLg(context), color: Colors.grey),
              const SizedBox(height: 16),
              Text('Vui lòng đăng nhập để xem thông tin.', style: TextStyle(fontSize: R.sp(context, 15), color: Colors.grey), textAlign: TextAlign.center),
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
                  padding: EdgeInsets.symmetric(horizontal: R.isSmall(context) ? 20 : 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Đăng nhập ngay', style: TextStyle(fontSize: R.sp(context, 14))),
              )
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: R.hPad(context) + 4),
              child: Column(
                children: [
                  SizedBox(height: R.isSmall(context) ? 12 : 16),
                  // Avatar Section
                  Center(
                    child: GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAvatarAndUpload,
                      child: Stack(
                        children: [
                          Container(
                            width: avatarSize,
                            height: avatarSize,
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
                      (_user!['role']?.toString().toLowerCase() == 'admin') 
                          ? 'Quản Trị Viên' 
                          : ((_user!['role']?.toString().toLowerCase() == 'vet' || _user!['role']?.toString().toLowerCase() == 'doctor')
                              ? 'Bác Sĩ'
                              : 'Khách Hàng'),
                      style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                    ),
                  ),
                  SizedBox(height: R.isSmall(context) ? 12 : 16),

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
                  SizedBox(height: R.isSmall(context) ? 10 : 12),

                  // Edit / Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_isEditing) _saveProfile();
                        else setState(() => _isEditing = true);
                      },
                      icon: Icon(_isEditing ? Icons.save : Icons.edit, size: R.iconSm(context)),
                      label: Text(_isEditing ? 'Lưu Thông Tin' : 'Chỉnh Sửa Thông Tin', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2E53),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 11 : 13),
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
                        child: Text('Hủy', style: TextStyle(fontSize: R.sp(context, 14), color: Colors.grey)),
                      ),
                    ),
                  ],

                  if (_user!['role']?.toString().toLowerCase() != 'admin' &&
                      _user!['role']?.toString().toLowerCase() != 'vet' &&
                      _user!['role']?.toString().toLowerCase() != 'doctor') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseHistoryScreen(user: _user!))),
                        icon: Icon(Icons.receipt_long, size: R.iconSm(context)),
                        label: Text('Lịch Sử Đơn Hàng', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF07E2B),
                          side: const BorderSide(color: Color(0xFFF07E2B)),
                          padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 11 : 13),
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
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('userInfo');
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                      },
                      icon: Icon(Icons.logout, size: R.iconSm(context)),
                      label: Text('Đăng Xuất', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 11 : 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  SizedBox(height: R.isSmall(context) ? 20 : 30),
                ],
              ),
            ),
          ),
        ),

        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F2E53)),
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
      padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(R.isSmall(context) ? 8 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4B5563), size: R.iconSm(context)),
          ),
          SizedBox(width: R.isSmall(context) ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: R.sp(context, 11), color: const Color(0xFF6B7280))),
                const SizedBox(height: 4),
                if (isEditable && controller != null)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(),
                    ),
                  )
                else
                  Text(value, style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.w600, color: const Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
