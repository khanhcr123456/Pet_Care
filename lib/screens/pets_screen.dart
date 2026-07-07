import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/screens/pet_detail_screen.dart';

class PetsScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final bool initialShowRegistration;
  
  const PetsScreen({super.key, this.user, this.initialShowRegistration = false});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  List<dynamic> _pets = [];
  bool _isLoadingPets = true;
  bool _isAddingPet = false;

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
  bool _isConfirmed = false;
  bool _isAgreedToTerms = false;
  bool _showRegistrationForm = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _showRegistrationForm = widget.initialShowRegistration;
    if (widget.user != null && widget.user!['token'] != null) {
      _fetchPets();
    } else {
      _isLoadingPets = false;
    }
  }

  Future<void> _fetchPets() async {
    try {
      final pets = await PetService().getPets(widget.user!['token']);
      setState(() {
        _pets = pets;
        _isLoadingPets = false;
      });
    } catch (e) {
      setState(() => _isLoadingPets = false);
    }
  }

  Future<void> _deletePet(String id) async {
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

    setState(() => _isLoadingPets = true);
    try {
      await PetService().deletePet(widget.user!['token'], id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa thú cưng')));
      }
      _fetchPets();
    } catch (e) {
      setState(() => _isLoadingPets = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa thú cưng: $e')));
      }
    }
  }

  Future<void> _addPet() async {
    if (widget.user == null || widget.user!['token'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để thêm thú cưng')));
      return;
    }
    if (_petNameController.text.trim().isEmpty || _selectedSpecies == null || _petAgeController.text.trim().isEmpty || _petWeightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đủ các trường bắt buộc (*)')));
      return;
    }
    if (!_isConfirmed || !_isAgreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng xác nhận và đồng ý với điều khoản')));
      return;
    }

    setState(() => _isAddingPet = true);
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
      final newPet = await PetService().addPet(widget.user!['token'], petData, imageFile: _selectedImage);
      
      _petNameController.clear();
      _petBreedController.clear();
      _petAgeController.clear();
      _petWeightController.clear();
      _petColorController.clear();
      _petAllergiesController.clear();
      _petNotesController.clear();
      setState(() {
        _showRegistrationForm = false;
        _selectedSpecies = null;
        _selectedGender = null;
        _selectedImage = null;
        _isSpayed = false;
        _isConfirmed = false;
        _isAgreedToTerms = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thú cưng thành công!')));
        if (widget.initialShowRegistration) {
          Navigator.pop(context, newPet['_id']);
          return;
        }
      }
      
      await _fetchPets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAddingPet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.user == null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Vui lòng đăng nhập để quản lý thú cưng', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
          ],
        ),
      );
    } else {
      content = SingleChildScrollView(
        child: Column(
          children: [
            _buildPetListSection(),
            if (_showRegistrationForm)
              _buildPetRegistrationSection()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showRegistrationForm = true),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm thú cưng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF07E2B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: widget.initialShowRegistration ? AppBar(
        title: const Text('Thêm Thú Cưng', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ) : null,
      body: content,
    );
  }

  Widget _buildPetListSection() {
    if (_isLoadingPets) {
      return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFF07E2B)));
    }
    if (_pets.isEmpty) {
       return const Padding(padding: EdgeInsets.all(20), child: Text('Bạn chưa có thú cưng nào. Hãy thêm ngay!'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh Sách Thú Cưng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pets.length,
            itemBuilder: (context, index) {
              final pet = _pets[index];
              final isDog = pet['species'] == 'Dog';
              return GestureDetector(
                onTap: () {
                  if (widget.user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetDetailScreen(
                          petId: pet['_id'],
                          user: widget.user!,
                        ),
                      ),
                    ).then((_) => _fetchPets());
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFD), // Light blue tint like in the image
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD9E8F5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        backgroundImage: (pet['avatar'] != null && pet['avatar'].toString().startsWith('http')) 
                            ? NetworkImage(pet['avatar']) 
                            : null,
                        child: (pet['avatar'] == null || !pet['avatar'].toString().startsWith('http'))
                            ? Text(isDog ? '🐶' : '🐱', style: const TextStyle(fontSize: 30))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pet['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                            const SizedBox(height: 4),
                            Text('${pet['age']} tuổi', style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deletePet(pet['_id']),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                    ],
                  ),
                ),
              );
            },
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
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
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
        value: value,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPetRegistrationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEBE6D6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Đăng ký thú cưng', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              IconButton(icon: const Icon(Icons.close, color: Color(0xFF4B5563)), onPressed: () => setState(() => _showRegistrationForm = false)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Điền các thông tin cơ bản của thú cưng, phục vụ cho việc cá nhân hóa hồ sơ với từng thú cưng.', style: TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
          const SizedBox(height: 20),
          
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
              Expanded(child: _buildTextField('Tuổi (năm) *', controller: _petAgeController, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Cân nặng (kg) *', controller: _petWeightController, isNumber: true)),
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
                    : null,
              ),
              child: _selectedImage == null 
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, color: Color(0xFF4B5563), size: 30),
                      SizedBox(height: 8),
                      Text('Kéo thả ảnh hoặc bấm để chọn', style: TextStyle(color: Color(0xFF4B5563))),
                    ],
                  )
                : const SizedBox.shrink(),
            ),
          ),
          
          _buildTextField('Dị ứng (cách nhau bằng dấu phẩy)', controller: _petAllergiesController),
          _buildTextField('Ghi chú đặc biệt', controller: _petNotesController, maxLines: 2),
          
          CheckboxListTile(
            value: _isSpayed,
            onChanged: (v) => setState(() => _isSpayed = v ?? false),
            title: const Text('Đã triệt sản', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          CheckboxListTile(
            value: _isConfirmed,
            onChanged: (v) => setState(() => _isConfirmed = v ?? false),
            title: const Text('Tôi xác nhận thông tin cung cấp là chính xác', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          CheckboxListTile(
            value: _isAgreedToTerms,
            onChanged: (v) => setState(() => _isAgreedToTerms = v ?? false),
            title: const Text('Tôi đồng ý với Điều khoản sử dụng & Chính sách bảo mật', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isAddingPet ? null : _addPet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDFDACB),
                    foregroundColor: const Color(0xFF0F4C81),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF0F4C81))),
                  ),
                  child: _isAddingPet
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Tạo hồ sơ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {}, // Clear form or something
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4B5563),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
