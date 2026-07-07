import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/screens/booking_screen.dart';

class PetDetailScreen extends StatefulWidget {
  final String petId;
  final Map<String, dynamic> user;

  const PetDetailScreen({super.key, required this.petId, required this.user});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  Map<String, dynamic>? _pet;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUpdating = false;

  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _petBreedController = TextEditingController();
  final TextEditingController _petAgeController = TextEditingController();
  final TextEditingController _petWeightController = TextEditingController();
  final TextEditingController _petColorController = TextEditingController();
  final TextEditingController _petAllergiesController = TextEditingController();
  final TextEditingController _petNotesController = TextEditingController();

  String? _selectedSpecies;
  String? _selectedGender;
  bool _isSpayed = false;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchPetDetails();
  }

  Future<void> _fetchPetDetails() async {
    try {
      final pet = await PetService().getPetById(widget.user['token'], widget.petId);
      setState(() {
        _pet = pet;
        _isLoading = false;
      });
      _populateEditForm();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _populateEditForm() {
    if (_pet == null) return;
    _petNameController.text = _pet!['name'] ?? '';
    _petBreedController.text = _pet!['breed'] ?? '';
    _petAgeController.text = _pet!['age']?.toString() ?? '';
    _petWeightController.text = _pet!['weight']?.toString() ?? '';
    _petColorController.text = _pet!['color'] ?? '';
    
    if (_pet!['allergies'] is List) {
      _petAllergiesController.text = (_pet!['allergies'] as List).join(', ');
    } else {
      _petAllergiesController.text = _pet!['allergies']?.toString() ?? '';
    }
    if (_petAllergiesController.text == '[]') _petAllergiesController.text = '';
    
    _petNotesController.text = _pet!['notes'] ?? '';
    _selectedSpecies = _pet!['species']?.toString().toLowerCase();
    _selectedGender = _pet!['gender']?.toString().toLowerCase();
    _isSpayed = _pet!['isSpayed'] == true;
  }

  Future<void> _updatePet() async {
    if (_petNameController.text.trim().isEmpty || _selectedSpecies == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên và chọn loài thú cưng')));
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final petData = {
        'name': _petNameController.text.trim(),
        'species': _selectedSpecies,
        'breed': _petBreedController.text.trim(),
        'gender': _selectedGender,
        'age': int.tryParse(_petAgeController.text.trim()) ?? 0,
        'weight': double.tryParse(_petWeightController.text.trim()) ?? 0.0,
        'color': _petColorController.text.trim(),
        'allergies': _petAllergiesController.text.trim(),
        'notes': _petNotesController.text.trim(),
        'isSpayed': _isSpayed,
      };
      
      if (_selectedImage == null && _pet!['avatar'] != null) {
        petData['avatar'] = _pet!['avatar'];
      }
      
      await PetService().updatePet(widget.user['token'], widget.petId, petData, imageFile: _selectedImage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thông tin thành công')));
      }
      
      setState(() {
        _isEditing = false;
        _isUpdating = false;
        _isLoading = true;
        _selectedImage = null;
      });
      _fetchPetDetails();
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
      }
    }
  }

  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa thú cưng này không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await PetService().deletePet(widget.user['token'], widget.petId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa thú cưng')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa thú cưng: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa thông tin' : 'Chi tiết thú cưng', style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.white, 
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
        actions: [
          if (!_isLoading && _pet != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deletePet,
            ),
          if (!_isLoading && _pet != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (_isEditing) {
                    _populateEditForm();
                    _selectedImage = null;
                  }
                });
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _pet == null
              ? const Center(child: Text('Không tìm thấy thông tin'))
              : _isEditing 
                  ? _buildEditForm()
                  : _buildPetDetails(),
    );
  }

  Widget _buildPetDetails() {
    final avatarUrl = _pet!['avatar'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: (avatarUrl != null && avatarUrl.toString().startsWith('http')) ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || !avatarUrl.toString().startsWith('http')) ? const Icon(Icons.pets, size: 50, color: Colors.grey) : null,
          ),
          const SizedBox(height: 16),
          Text(_pet!['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
          const SizedBox(height: 24),
          _buildInfoRow('Loài', _translateSpecies(_pet!['species']?.toString())),
          _buildInfoRow('Giống loài', _pet!['breed']),
          _buildInfoRow('Giới tính', _pet!['gender'] == 'male' ? 'Đực' : (_pet!['gender'] == 'female' ? 'Cái' : _pet!['gender'])),
          _buildInfoRow('Tuổi', '${_pet!['age']} năm'),
          _buildInfoRow('Cân nặng', '${_pet!['weight']} kg'),
          _buildInfoRow('Màu sắc', _pet!['color']),
          _buildInfoRow(
            'Dị ứng', 
            (_pet!['allergies'] == null || _pet!['allergies'].toString().trim().isEmpty || _pet!['allergies'].toString() == '[]') 
                ? 'Không có' 
                : (_pet!['allergies'] is List ? (_pet!['allergies'] as List).join(', ') : _pet!['allergies'].toString())
          ),
          _buildInfoRow('Đã triệt sản', _pet!['isSpayed'] == true ? 'Rồi' : 'Chưa'),
          _buildInfoRow('Ghi chú', _pet!['notes']),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingScreen(
                    user: widget.user,
                    initialPetId: widget.petId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month),
            label: const Text('Đặt lịch khám cho bé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF07E2B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value.toString(), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _translateSpecies(String? species) {
    if (species == null) return '';
    switch (species.toLowerCase()) {
      case 'dog': return 'Chó';
      case 'cat': return 'Mèo';
      case 'bird': return 'Chim';
      case 'hamster': return 'Chuột Hamster';
      case 'rabbit': return 'Thỏ';
      case 'fish': return 'Cá';
      case 'other': return 'Khác';
      default: return species;
    }
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Tên thú cưng *', controller: _petNameController),
          _buildDropdown(
            'Chọn loài *', 
            {
              'dog': 'Chó',
              'cat': 'Mèo',
              'bird': 'Chim',
              'hamster': 'Chuột Hamster',
              'rabbit': 'Thỏ',
              'fish': 'Cá',
              'other': 'Khác',
            }, 
            _selectedSpecies, 
            (v) => setState(() => _selectedSpecies = v)
          ),
          
          Row(
            children: [
              Expanded(child: _buildTextField('Giống loài', controller: _petBreedController)),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown(
                'Giới tính', 
                {
                  'male': 'Đực',
                  'female': 'Cái',
                }, 
                _selectedGender, 
                (v) => setState(() => _selectedGender = v)
              )),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('Tuổi (năm)', controller: _petAgeController, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Cân nặng (kg)', controller: _petWeightController, isNumber: true)),
            ],
          ),
          
          _buildTextField('Màu sắc', controller: _petColorController),
          
          GestureDetector(
            onTap: () async {
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() => _selectedImage = File(image.path));
              }
            },
            child: Container(
              width: double.infinity,
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDFDACB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9CA3AF), style: BorderStyle.solid),
                image: _selectedImage != null 
                    ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                    : ((_pet!['avatar'] != null && _pet!['avatar'].toString().startsWith('http'))
                        ? DecorationImage(image: NetworkImage(_pet!['avatar']), fit: BoxFit.cover)
                        : null),
              ),
              child: (_selectedImage == null && (_pet!['avatar'] == null || !_pet!['avatar'].toString().startsWith('http')))
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, color: Color(0xFF4B5563), size: 30),
                      SizedBox(height: 8),
                      Text('Đổi ảnh đại diện', style: TextStyle(color: Color(0xFF4B5563))),
                    ],
                  )
                : const SizedBox.shrink(),
            ),
          ),
          
          _buildTextField('Dị ứng (cách nhau bằng dấu phẩy)', controller: _petAllergiesController),
          _buildTextField('Ghi chú đặc biệt', controller: _petNotesController, maxLines: 2),
          
          CheckboxListTile(
            title: const Text('Đã triệt sản'),
            value: _isSpayed,
            onChanged: (v) => setState(() => _isSpayed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFFF07E2B),
          ),
          
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isUpdating ? null : _updatePet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF07E2B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUpdating 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lưu thông tin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, {TextEditingController? controller, bool isNumber = false, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, Map<String, String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        hint: Text(hint, style: const TextStyle(color: Color(0xFF4B5563))),
        value: items.containsKey(value) ? value : null,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
