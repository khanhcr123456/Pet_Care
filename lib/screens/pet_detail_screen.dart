import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/services/booking_service.dart';
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
  List<dynamic> _upcomingAppointments = [];
  bool _isLoadingAppointments = true;

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
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final data = await BookingService().getAppointments(widget.user['token'], limit: 100);
      final petId = widget.petId;
      final upcoming = data.where((appt) {
        final apptPet = appt['pet'];
        final apptPetId = apptPet is Map ? (apptPet['_id'] ?? apptPet['id']) : apptPet;
        final status = (appt['status']?.toString().toLowerCase() ?? 'pending');
        return apptPetId == petId && status != 'completed' && status != 'cancelled';
      }).toList();
      
      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAppointments = false);
      }
    }
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
          const SizedBox(height: 8),
          _buildUpcomingAppointmentsSection(),
          const SizedBox(height: 16),
          _buildMedicalHistorySection(),
          const SizedBox(height: 16),
          _buildVaccineHistorySection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.toString(), style: const TextStyle(color: Color(0xFF0F2E53), fontWeight: FontWeight.w600, fontSize: 14)),
          ),
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
          _buildLabeledField('Tên thú cưng *', controller: _petNameController),

          // Loài (dropdown)
          _buildLabel('Loài *'),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDFDACB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ['dog','cat','bird','hamster','rabbit','fish','other'].contains(_selectedSpecies) ? _selectedSpecies : null,
                isExpanded: true,
                hint: const Text('Chọn loài', style: TextStyle(color: Color(0xFF4B5563))),
                items: const [
                  DropdownMenuItem(value: 'dog', child: Text('Chó')),
                  DropdownMenuItem(value: 'cat', child: Text('Mèo')),
                  DropdownMenuItem(value: 'bird', child: Text('Chim')),
                  DropdownMenuItem(value: 'hamster', child: Text('Chuột Hamster')),
                  DropdownMenuItem(value: 'rabbit', child: Text('Thỏ')),
                  DropdownMenuItem(value: 'fish', child: Text('Cá')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => _selectedSpecies = v),
              ),
            ),
          ),

          Row(
            children: [
              Expanded(child: _buildLabeledField('Giống loài', controller: _petBreedController)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Giới tính'),
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFDACB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: {'male': 'male', 'female': 'female'}.containsKey(_selectedGender) ? _selectedGender : null,
                          isExpanded: true,
                          hint: const Text('Giới tính', style: TextStyle(color: Color(0xFF4B5563))),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Đực')),
                            DropdownMenuItem(value: 'female', child: Text('Cái')),
                          ],
                          onChanged: (v) => setState(() => _selectedGender = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(child: _buildLabeledField('Tuổi (năm) *', controller: _petAgeController, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildLabeledField('Cân nặng (kg) *', controller: _petWeightController, isNumber: true)),
            ],
          ),

          _buildLabeledField('Màu sắc', controller: _petColorController),

          // Avatar image picker
          _buildLabel('Ảnh đại diện'),
          GestureDetector(
            onTap: () async {
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) setState(() => _selectedImage = File(image.path));
            },
            child: Container(
              width: double.infinity,
              height: 200,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDFDACB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9CA3AF)),
              ),
              clipBehavior: Clip.hardEdge,
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity)
                  : (_pet!['avatar'] != null && _pet!['avatar'].toString().startsWith('http'))
                      ? Image.network(_pet!['avatar'], fit: BoxFit.cover, width: double.infinity)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: Color(0xFF4B5563), size: 36),
                            SizedBox(height: 8),
                            Text('Nhấn để chọn ảnh', style: TextStyle(color: Color(0xFF4B5563))),
                          ],
                        ),
            ),
          ),

          _buildLabeledField('Dị ứng (cách nhau bằng dấu phẩy)', controller: _petAllergiesController),
          _buildLabeledField('Ghi chú đặc biệt', controller: _petNotesController, maxLines: 2),

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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
    );
  }

  Widget _buildLabeledField(String label, {TextEditingController? controller, bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFDFDACB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
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

  Widget _buildUpcomingAppointmentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.calendar_today, color: Color(0xFF0F4C81), size: 20),
                    SizedBox(width: 8),
                    Text('Lịch hẹn sắp tới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(
                          user: widget.user,
                          initialPetId: widget.petId,
                        ),
                      ),
                    ).then((_) {
                      setState(() => _isLoadingAppointments = true);
                      _fetchAppointments();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE06C3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('+ Đặt lịch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_isLoadingAppointments)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_upcomingAppointments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('Chưa có lịch hẹn sắp tới', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ..._upcomingAppointments.map((appt) {
              final dateStr = appt['date'] ?? '';
              String formattedDate = dateStr;
              if (dateStr.isNotEmpty) {
                final parts = dateStr.split('-');
                if (parts.length >= 3) {
                  final day = parts[2].split('T')[0];
                  formattedDate = '$day/${parts[1]}/${parts[0]}';
                }
              }
              String startTime = '';
              if (appt['timeSlot'] != null && appt['timeSlot'] is Map) {
                startTime = appt['timeSlot']['startTime'] ?? '';
              } else if (appt['startTime'] != null) {
                startTime = appt['startTime'];
              }

              final vetName = (appt['vet'] is Map) ? (appt['vet']['fullName'] ?? appt['vet']['name'] ?? 'Bác sĩ') : 'Bác sĩ';
              final serviceName = (appt['service'] is Map) ? (appt['service']['name'] ?? 'Dịch vụ') : 'Dịch vụ';
              final status = (appt['status']?.toString().toLowerCase() ?? 'pending');
              
              Color statusColor = Colors.orange;
              String statusText = 'Chờ xác nhận';
              if (status == 'confirmed') {
                statusColor = Colors.blue;
                statusText = 'Đã xác nhận';
              }

              return Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(startTime.isNotEmpty ? startTime : '--:--', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                          const SizedBox(height: 4),
                          Text(formattedDate.isNotEmpty ? formattedDate : '--/--/----', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(serviceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                            const SizedBox(height: 4),
                            Text('BS. $vetName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 26,
                            child: OutlinedButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Xác nhận hủy'),
                                    content: const Text('Bạn có chắc chắn muốn hủy lịch khám này không?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Có, hủy', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (!mounted) return;
                                  try {
                                    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                                    final apptId = appt['_id'] ?? appt['id'];
                                    await BookingService().cancelAppointment(widget.user['token'], apptId);
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hủy lịch thành công')));
                                    setState(() => _isLoadingAppointments = true);
                                    _fetchAppointments();
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('Hủy', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMedicalHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Icon(Icons.favorite_border, color: Color(0xFF0F4C81), size: 20),
                SizedBox(width: 8),
                Text('Lịch sử khám bệnh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Tất cả dịch vụ', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('mm/dd/yyyy', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        Icon(Icons.calendar_today, size: 14, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text('Không tìm thấy lịch sử nào khớp với điều kiện lọc', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Icon(Icons.vaccines, color: Color(0xFF0F4C81), size: 20),
                SizedBox(width: 8),
                Text('Lịch sử Vaccine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text('Chưa có lịch sử tiêm vaccine', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
