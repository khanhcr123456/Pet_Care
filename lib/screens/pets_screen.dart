import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/screens/pet_detail_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

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
                padding: EdgeInsets.symmetric(horizontal: R.hPad(context) + 4, vertical: 10.0),
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showRegistrationForm = true),
                  icon: const Icon(Icons.add),
                  label: Text('Thêm thú cưng', style: TextStyle(fontSize: R.sp(context, 14))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF07E2B),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, R.isSmall(context) ? 46 : 50),
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
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thú Cưng Của Tôi', style: TextStyle(fontSize: R.sp(context, 21), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_pets.isEmpty) {
       return const Padding(padding: EdgeInsets.all(20), child: Text('Bạn chưa có thú cưng nào. Hãy thêm ngay!'));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thú Cưng Của Tôi', style: TextStyle(fontSize: R.sp(context, 21), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
          const SizedBox(height: 4),
          Text('${_pets.length} thú cưng', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 12))),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pets.length,
            itemBuilder: (context, index) {
              final pet = _pets[index];
              final species = (pet['species'] ?? '').toString().toLowerCase();
              final isDog = species == 'dog';
              final isCat = species == 'cat';
              final emoji = isDog ? '🐶' : isCat ? '🐱' : '🐾';
              final String speciesLabel = isDog ? 'Chó' : isCat ? 'Mèo' : pet['species'] ?? '';
              const List<Color> gradientColors = [Color(0xFFFFF8F0), Color(0xFFFFEDD8)];
              const Color accentColor = Color(0xFFF07E2B);

              return GestureDetector(
                onTap: () {
                  if (widget.user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PetDetailScreen(petId: pet['_id'], user: widget.user!)),
                    ).then((_) => _fetchPets());
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: accentColor.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: R.isSmall(context) ? 62 : 72,
                          height: R.isSmall(context) ? 62 : 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: accentColor, width: 2.5),
                            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8)],
                          ),
                          child: ClipOval(
                            child: (pet['avatar'] != null && pet['avatar'].toString().startsWith('http'))
                                ? Image.network(pet['avatar'], fit: BoxFit.cover)
                                : Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pet['name'] ?? '',
                                    style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(speciesLabel, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _petTag(Icons.cake_outlined, '${pet['age']} tuổi', accentColor),
                                  if (pet['breed'] != null && pet['breed'].toString().isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    _petTag(Icons.pets, pet['breed'], accentColor),
                                  ],
                                ],
                              ),
                              if (pet['weight'] != null) ...[
                                const SizedBox(height: 4),
                                _petTag(Icons.monitor_weight_outlined, '${pet['weight']} kg', accentColor),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: accentColor, size: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _petTag(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTextField(String hint, {TextEditingController? controller, bool isNumber = false, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        style: TextStyle(fontSize: R.sp(context, 14)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: const Color(0xFF9CA3AF), fontSize: R.sp(context, 13)),
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: R.isSmall(context) ? 11 : 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, Map<String, String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: R.isSmall(context) ? 10 : 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: R.isSmall(context) ? 11 : 14),
        ),
        hint: Text(hint, style: TextStyle(color: const Color(0xFF4B5563), fontSize: R.sp(context, 13))),
        value: value,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPetRegistrationSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.hPad(context) + 4, vertical: 10),
      padding: EdgeInsets.all(R.isSmall(context) ? 16 : 20),
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
              Text('Đăng ký thú cưng', style: TextStyle(fontSize: R.sp(context, 20), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
              IconButton(icon: const Icon(Icons.close, color: Color(0xFF4B5563)), onPressed: () => setState(() => _showRegistrationForm = false)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Điền các thông tin cơ bản của thú cưng, phục vụ cho việc cá nhân hóa hồ sơ với từng thú cưng.', style: TextStyle(color: const Color(0xFF4B5563), fontSize: R.sp(context, 13))),
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
            title: Text('Đã triệt sản', style: TextStyle(fontSize: R.sp(context, 13), color: const Color(0xFF4B5563))),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          CheckboxListTile(
            value: _isConfirmed,
            onChanged: (v) => setState(() => _isConfirmed = v ?? false),
            title: Text('Tôi xác nhận thông tin cung cấp là chính xác', style: TextStyle(fontSize: R.sp(context, 13), color: const Color(0xFF4B5563))),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          CheckboxListTile(
            value: _isAgreedToTerms,
            onChanged: (v) => setState(() => _isAgreedToTerms = v ?? false),
            title: Text('Tôi đồng ý với Điều khoản sử dụng & Chính sách bảo mật', style: TextStyle(fontSize: R.sp(context, 13), color: const Color(0xFF4B5563))),
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
                    padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 13 : 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF0F4C81))),
                  ),
                  child: _isAddingPet
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Tạo hồ sơ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 15))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {}, // Clear form or something
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4B5563),
                    padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 13 : 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Hủy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 15))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
