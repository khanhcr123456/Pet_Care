import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/config/app_config.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/services/booking_service.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:shimmer/shimmer.dart';

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
  List<dynamic> _medicalHistory = [];
  List<dynamic> _vaccineHistory = [];
  Map<String, String> _vetNames = {};
  Map<String, String> _apptTimes = {};
  Map<String, String> _apptVetNames = {};
  Map<String, String> _apptToVaccine = {};
  Map<String, String> _apptToHealthRecord = {};
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
      final results = await Future.wait([
        BookingService().getAllAppointments(widget.user['token'], limit: 100, petId: widget.petId),
        BookingService().getVaccinationsByPetId(widget.user['token'], widget.petId),
        BookingService().getHealthRecordsByPetId(widget.user['token'], widget.petId),
        AuthService().getVets(limit: 100).catchError((e) { print('Error fetching vets: $e'); return []; }),
      ]);
      final data = results[0];
      final vaccines = results[1];
      final healthRecords = results[2];
      final vetsList = results[3];
      
      final petId = widget.petId;
      final upcoming = <dynamic>[];
      final medicalHistory = <dynamic>[];
      final vaccineHistory = vaccines;
      final Map<String, String> vetNames = {};
      final Map<String, String> apptTimes = {};
      final Map<String, String> apptVetNames = {};
      final Map<String, String> apptToVaccine = {};
      final Map<String, String> apptToHealthRecord = {};
      
      for (var vet in vetsList) {
        final vId = vet['_id']?.toString() ?? vet['id']?.toString();
        final vName = vet['fullName']?.toString() ?? vet['name']?.toString();
        if (vId != null && vName != null) {
          vetNames[vId] = vName;
        }
      }
      
      for (var appt in data) {
        final aId = appt['_id']?.toString() ?? appt['id']?.toString();
        if (aId != null) {
          String startTime = '';
          if (appt['timeSlot'] != null && appt['timeSlot'] is Map) {
            startTime = appt['timeSlot']['startTime']?.toString() ?? '';
          } else if (appt['startTime'] != null) {
            startTime = appt['startTime'].toString();
          }
          if (startTime.isNotEmpty) {
            apptTimes[aId] = startTime;
          }
        }

        if (appt['vet'] is Map) {
          final vId = appt['vet']['_id']?.toString() ?? appt['vet']['id']?.toString();
          final vName = appt['vet']['fullName']?.toString() ?? appt['vet']['name']?.toString();
          if (vId != null && vName != null) {
            vetNames[vId] = vName;
          }
          if (aId != null && vName != null) {
            apptVetNames[aId] = vName;
          }
        }
        final apptPet = appt['pet'];
        final apptPetId = apptPet is Map ? (apptPet['_id'] ?? apptPet['id']) : apptPet;
        if (apptPetId != petId) continue;
        
        final status = (appt['status']?.toString().toLowerCase() ?? 'pending').replaceAll(' ', '_');
        
        if (status == 'hoàn_thành' || status == 'completed') {
          medicalHistory.add(appt);
        } else if (status != 'đã_hủy' && status != 'cancelled') {
          upcoming.add(appt);
        }
      }

      for (var vax in vaccines) {
        final vId = vax['_id']?.toString() ?? vax['id']?.toString();
        final aId = vax['appointment'] is Map ? (vax['appointment']['_id'] ?? vax['appointment']['id'])?.toString() : vax['appointment']?.toString();
        if (vId != null && aId != null) {
          apptToVaccine[aId] = vId;
        }
      }

      for (var hr in healthRecords) {
        final hrId = hr['_id']?.toString() ?? hr['id']?.toString();
        final aId = hr['appointment'] is Map ? (hr['appointment']['_id'] ?? hr['appointment']['id'])?.toString() : hr['appointment']?.toString();
        if (hrId != null && aId != null) {
          apptToHealthRecord[aId] = hrId;
        }
      }

      int compareApps(dynamic a, dynamic b, {bool newestFirst = true}) {
        DateTime aDate = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        DateTime bDate = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        
        String aTime = '';
        if (a['timeSlot'] != null && a['timeSlot'] is Map) {
          aTime = a['timeSlot']['startTime']?.toString() ?? '';
        } else {
          aTime = a['startTime']?.toString() ?? '';
        }
        
        String bTime = '';
        if (b['timeSlot'] != null && b['timeSlot'] is Map) {
          bTime = b['timeSlot']['startTime']?.toString() ?? '';
        } else {
          bTime = b['startTime']?.toString() ?? '';
        }

        if (aTime.isNotEmpty && aTime.contains(':')) {
          final parts = aTime.split(':');
          if (parts.length >= 2) {
            int h = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (aTime.toLowerCase().contains('pm') && h < 12) h += 12;
            if (aTime.toLowerCase().contains('am') && h == 12) h = 0;
            aDate = DateTime(aDate.year, aDate.month, aDate.day, h, m);
          }
        }
        if (bTime.isNotEmpty && bTime.contains(':')) {
          final parts = bTime.split(':');
          if (parts.length >= 2) {
            int h = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (bTime.toLowerCase().contains('pm') && h < 12) h += 12;
            if (bTime.toLowerCase().contains('am') && h == 12) h = 0;
            bDate = DateTime(bDate.year, bDate.month, bDate.day, h, m);
          }
        }
        return newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
      }

      upcoming.sort((a, b) => compareApps(a, b, newestFirst: false));
      medicalHistory.sort((a, b) => compareApps(a, b, newestFirst: true));

      vaccineHistory.sort((a, b) {
        DateTime aDate = DateTime.now();
        if (a['dateAdministered'] != null) {
          aDate = DateTime.tryParse(a['dateAdministered'].toString()) ?? aDate;
        } else if (a['date'] != null) {
          aDate = DateTime.tryParse(a['date'].toString()) ?? aDate;
        }

        DateTime bDate = DateTime.now();
        if (b['dateAdministered'] != null) {
          bDate = DateTime.tryParse(b['dateAdministered'].toString()) ?? bDate;
        } else if (b['date'] != null) {
          bDate = DateTime.tryParse(b['date'].toString()) ?? bDate;
        }
        
        return bDate.compareTo(aDate); // newest first
      });

      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _medicalHistory = medicalHistory;
          _vaccineHistory = vaccineHistory;
          _vetNames = vetNames;
          _apptTimes = apptTimes;
          _apptVetNames = apptVetNames;
          _apptToVaccine = apptToVaccine;
          _apptToHealthRecord = apptToHealthRecord;
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
    final bool isVet = widget.user['role']?.toString().toLowerCase() == 'vet';
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa thông tin' : 'Chi tiết thú cưng', style: const TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.white, 
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
        actions: [
          if (!_isLoading && _pet != null && !_isEditing && !isVet)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deletePet,
            ),
          if (!_isLoading && _pet != null && !isVet)
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
          ? Padding(
              padding: EdgeInsets.all(R.hPad(context)),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(radius: 50, backgroundColor: Colors.white),
                    const SizedBox(height: 16),
                    Container(height: 24, width: 150, color: Colors.white),
                    const SizedBox(height: 24),
                    for (int i = 0; i < 5; i++)
                      Container(height: 50, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
              ),
            )
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
      padding: EdgeInsets.all(R.hPad(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: (avatarUrl != null && avatarUrl.toString().startsWith('http')) ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || !avatarUrl.toString().startsWith('http')) ? Icon(Icons.pets, size: 50, color: Colors.grey) : null,
          ),
          SizedBox(height: 16),
          Text(_pet!['name'] ?? '', style: TextStyle(fontSize: R.sp(context, 24), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
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
      padding: EdgeInsets.all(R.hPad(context)),
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
              margin: EdgeInsets.only(bottom: 16),
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
                      : Column(
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
            title: Text('Đã triệt sản'),
            value: _isSpayed,
            onChanged: (v) => setState(() => _isSpayed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFFF07E2B),
          ),

          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isUpdating ? null : _updatePet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF07E2B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUpdating
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Lưu thông tin', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
    );
  }

  Widget _buildLabeledField(String label, {TextEditingController? controller, bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFDFDACB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 14),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTextField(String hint, {TextEditingController? controller, bool isNumber = false, int maxLines = 1}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, Map<String, String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFDFDACB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 14),
        ),
        hint: Text(hint, style: const TextStyle(color: Color(0xFF4B5563))),
        value: items.containsKey(value) ? value : null,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildUpcomingAppointmentsSection() {
    final bool isVet = widget.user['role']?.toString().toLowerCase() == 'vet';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Color(0xFF0F4C81), size: 20),
                    SizedBox(width: 8),
                    Text('Lịch hẹn sắp tới', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                  ],
                ),
                if (!isVet)
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
                    padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('+ Đặt lịch', style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_isLoadingAppointments)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (_upcomingAppointments.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('Chưa có lịch hẹn sắp tới', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
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
              final isVaccine = serviceName.toString().toLowerCase().contains('tiêm') || serviceName.toString().toLowerCase().contains('vaccine');
              final status = (appt['status']?.toString().toLowerCase() ?? 'chờ_xác_nhận').replaceAll(' ', '_');
              Color statusColor = Colors.orange;
              String statusText = 'Chờ xác nhận';
              if (status == 'đã_xác_nhận' || status == 'confirmed') {
                statusColor = Colors.blue;
                statusText = 'Đã xác nhận';
              } else if (status == 'đang_khám' || status == 'in_progress') {
                statusColor = Colors.purple;
                statusText = isVaccine ? 'Đang tiêm' : 'Đang khám';
              } else if (status == 'hoàn_thành' || status == 'completed') {
                statusColor = Colors.green;
                statusText = 'Hoàn thành';
              } else if (status == 'đã_hủy' || status == 'cancelled') {
                statusColor = Colors.red;
                statusText = 'Đã hủy';
              }

              return Padding(
                padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(startTime.isNotEmpty ? startTime : '--:--', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                              SizedBox(height: 4),
                              Text(formattedDate.isNotEmpty ? formattedDate : '--/--/----', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey)),
                            ],
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(serviceName, style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text('BS. $vetName', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(statusText, style: TextStyle(fontSize: R.sp(context, 10), color: statusColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isVet && status != 'hoàn_thành' && status != 'completed' && status != 'đã_hủy' && status != 'cancelled') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () async {
                              String newStatus = '';
                              if (status == 'chờ_xác_nhận' || status == 'pending') newStatus = 'đã_xác_nhận';
                              else if (status == 'đã_xác_nhận' || status == 'confirmed') newStatus = 'đang_khám';
                              else if (status == 'đang_khám' || status == 'in_progress') {
                                if (isVaccine) {
                                  _showVaccinationForm(appt);
                                } else {
                                  _showMedicalForm(appt);
                                }
                                return;
                              }
                              
                              if (newStatus.isEmpty) return;
                              
                              try {
                                final apptId = appt['_id'] ?? appt['id'];
                                await BookingService().updateAppointmentStatus(widget.user['token'], apptId, newStatus);
                                
                                // --- THÊM TÍNH NĂNG THÔNG BÁO ---
                                if (newStatus == 'đã_xác_nhận') {
                                  final String ownerId = (appt['user'] is Map) ? (appt['user']['_id'] ?? appt['user']['id'])?.toString() ?? '' : ((appt['userId'] is Map) ? (appt['userId']['_id'] ?? appt['userId']['id'])?.toString() ?? '' : (appt['userId'] ?? appt['user'])?.toString() ?? '');
                                  final petName = _pet?['name'] ?? ((appt['pet'] is Map) ? (appt['pet']['name'] ?? 'Thú cưng') : 'Thú cưng');
                                  if (ownerId.isNotEmpty) {
                                    try {
                                      await BookingService().sendPushNotification(
                                        token: widget.user['token'],
                                        userId: ownerId,
                                        title: 'Lịch hẹn được xác nhận!',
                                        body: 'Bác sĩ đã xác nhận lịch hẹn cho bé $petName.',
                                        data: {'appointmentId': apptId.toString(), 'status': newStatus},
                                      );
                                    } catch (_) {}
                                  }
                                }
                                // ---------------------------------
                                
                                if (!mounted) return;
                                // Update state locally — no need for full reload
                                setState(() {
                                  appt['status'] = newStatus;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật trạng thái thành công')));
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF07E2B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text(
                              (status == 'chờ_xác_nhận' || status == 'pending') ? 'Xác nhận lịch hẹn' : ((status == 'đã_xác_nhận' || status == 'confirmed') ? (isVaccine ? 'Bắt đầu tiêm phòng' : 'Bắt đầu khám bệnh') : 'Nhập kết quả'),
                              style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                      if (!isVet && status != 'hoàn_thành' && status != 'completed' && status != 'đã_hủy' && status != 'cancelled' && status != 'đang_khám' && status != 'in_progress') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Hủy lịch hẹn', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            child: Row(
              children: [
                Icon(Icons.favorite_border, color: Color(0xFF0F4C81), size: 20),
                SizedBox(width: 8),
                Text('Lịch sử lịch hẹn', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tất cả dịch vụ', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.black87)),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('mm/dd/yyyy', style: TextStyle(fontSize: R.sp(context, 13), color: Colors.black87)),
                        Icon(Icons.calendar_today, size: 14, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_medicalHistory.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('Không tìm thấy lịch sử nào', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            ..._medicalHistory.map((appt) => _buildHistoryItem(appt)).toList(),
          ],
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
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            child: Row(
              children: [
                Icon(Icons.vaccines, color: Color(0xFF0F4C81), size: 20),
                SizedBox(width: 8),
                Text('Lịch sử Vaccine', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_vaccineHistory.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('Chưa có lịch sử tiêm vaccine', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            ..._vaccineHistory.map((vax) => _buildVaccineHistoryItem(vax)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVaccineHistoryItem(dynamic vax) {
    String formattedDate = '';
    String time = '--:--';
    
    if (vax['date'] != null) {
      final isoStr = vax['date'].toString();
      final parts = isoStr.split('T');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        if (dateParts.length >= 3) {
          formattedDate = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
        }
      }
    } else if (vax['dateAdministered'] != null) {
      final isoStr = vax['dateAdministered'].toString();
      final parts = isoStr.split('T');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        if (dateParts.length >= 3) {
          formattedDate = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
        }
      }
    }

    final apptId = vax['appointment'] is Map ? (vax['appointment']['_id'] ?? vax['appointment']['id'])?.toString() : vax['appointment']?.toString();
    if (apptId != null && _apptTimes.containsKey(apptId)) {
      time = _apptTimes[apptId]!;
    } else if (vax['dateAdministered'] != null) {
      final isoStr = vax['dateAdministered'].toString();
      final parts = isoStr.split('T');
      if (parts.length == 2) {
        time = parts[1].substring(0, 5);
      }
    } else if (vax['date'] != null) {
      final isoStr = vax['date'].toString();
      final parts = isoStr.split('T');
      if (parts.length == 2) {
        time = parts[1].substring(0, 5);
      }
    }

    String vetName = 'Bác sĩ';
    final vetId = vax['vet'] is Map ? (vax['vet']['_id'] ?? vax['vet']['id'])?.toString() : vax['vet']?.toString();
    
    if (apptId != null && _apptVetNames.containsKey(apptId)) {
      vetName = 'BS. ${_apptVetNames[apptId]}';
    } else if (vetId != null && _vetNames.containsKey(vetId)) {
      vetName = 'BS. ${_vetNames[vetId]}';
    } else if (vax['vet'] is Map) {
      vetName = 'BS. ${vax['vet']['fullName'] ?? vax['vet']['name'] ?? ''}';
    }
    
    final vaccineName = vax['vaccineName'] ?? vax['name'] ?? 'Thuốc tiêm';

    return Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                SizedBox(height: 4),
                Text(formattedDate.isNotEmpty ? formattedDate : '--/--/----', style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vaccineName, style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(vetName, style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.w600, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Đã tiêm', style: TextStyle(fontSize: R.sp(context, 10), color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(dynamic appt) {
    String formattedDate = '';
    if (appt['date'] != null) {
      final parts = appt['date'].toString().split('T')[0].split('-');
      if (parts.length >= 3) {
        formattedDate = '${parts[2]}/${parts[1]}/${parts[0]}';
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
    final apptId = appt['_id']?.toString() ?? appt['id']?.toString();
    final bool hasVaccine = apptId != null && _apptToVaccine.containsKey(apptId);
    final bool hasHealthRecord = apptId != null && _apptToHealthRecord.containsKey(apptId);

    return Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(startTime.isNotEmpty ? startTime : '--:--', style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                    SizedBox(height: 4),
                    Text(formattedDate.isNotEmpty ? formattedDate : '--/--/----', style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('BS. $vetName', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.w600, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Hoàn thành', style: TextStyle(fontSize: R.sp(context, 10), color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasVaccine) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => _showVaccinationDetails(_apptToVaccine[apptId]!),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F4C81)),
                    foregroundColor: const Color(0xFF0F4C81),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Xem thông tin bản tiêm', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                ),
              ),
            ] else if (hasHealthRecord) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => _showHealthRecordDetails(_apptToHealthRecord[apptId]!),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F4C81)),
                    foregroundColor: const Color(0xFF0F4C81),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Xem kết quả', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showHealthRecordDetails(String hrId) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final hrData = await BookingService().getHealthRecordById(widget.user['token'], hrId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      final generalAssessment = hrData['generalAssessment'] ?? hrData['diagnosis'] ?? 'Không có thông tin';
      final consultation = hrData['consultation'] ?? hrData['notes'] ?? 'Không có';
      final weight = hrData['weight']?.toString() ?? '--';
      final temperature = hrData['temperature']?.toString() ?? '--';
      
      String dateAdmin = '';
      if (hrData['examinationDate'] != null) {
        final p = hrData['examinationDate'].toString().split('T')[0].split('-');
        if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
      } else if (hrData['date'] != null) {
        final p = hrData['date'].toString().split('T')[0].split('-');
        if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
      }

      // Parse images from API response
      final List<String> imageUrls = [];
      final rawImages = hrData['images'];
      if (rawImages is List) {
        for (var img in rawImages) {
          if (img is String && img.isNotEmpty) {
            imageUrls.add(img);
          } else if (img is Map) {
            final url = img['url']?.toString() ?? img['path']?.toString() ?? '';
            if (url.isNotEmpty) imageUrls.add(url);
          }
        }
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Kết quả khám bệnh', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Ngày khám:', dateAdmin.isNotEmpty ? dateAdmin : '--/--/----'),
                _buildDetailRow('Đánh giá chung:', generalAssessment),
                _buildDetailRow('Tư vấn:', consultation),
                _buildDetailRow('Cân nặng:', '$weight kg'),
                _buildDetailRow('Nhiệt độ:', '$temperature °C'),
                if (imageUrls.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text('Hình ảnh', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: imageUrls.map((url) => GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (c) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: Color(0xFF0F4C81))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tải thông tin: $e')));
    }
  }

  void _showVaccinationDetails(String vaxId) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final vaxData = await BookingService().getVaccinationById(widget.user['token'], vaxId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      final vaxName = vaxData['vaccineName'] ?? vaxData['name'] ?? 'Không xác định';
      final disease = vaxData['disease'] ?? 'Không có thông tin';
      final status = vaxData['status'] ?? 'Đã tiêm';
      String dateAdmin = '';
      if (vaxData['dateAdministered'] != null) {
        final p = vaxData['dateAdministered'].toString().split('T')[0].split('-');
        if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
      }
      String nextDate = '';
      if (vaxData['nextDate'] != null) {
        final p = vaxData['nextDate'].toString().split('T')[0].split('-');
        if (p.length >= 3) nextDate = '${p[2]}/${p[1]}/${p[0]}';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Thông tin tiêm phòng', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tên vaccine:', vaxName),
              _buildDetailRow('Ngày tiêm:', dateAdmin.isNotEmpty ? dateAdmin : '--/--/----'),
              _buildDetailRow('Trạng thái:', status),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: Color(0xFF0F4C81))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tải thông tin: $e')));
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showVaccinationForm(dynamic appt) {
    final TextEditingController vaccineNameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nhập kết quả tiêm phòng', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
              const SizedBox(height: 20),
            Text('Tên thuốc tiêm / Bệnh tiêm phòng', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: vaccineNameController,
              decoration: InputDecoration(
                hintText: 'Nhập tên vaccine...',
                hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (vaccineNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên vaccine')));
                        return;
                      }
                      Navigator.pop(ctx);
                      
                      try {
                        showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                        
                        final apptId = appt['_id'] ?? appt['id'];
                        final apptVetId = (appt['vet'] is Map) ? (appt['vet']['_id'] ?? appt['vet']['id']) : (appt['vet'] ?? widget.user['id']);
                        final dateStr = (appt['date'] != null && appt['date'] != '---') ? appt['date'] : DateTime.now().toIso8601String();
                        
                        final payload = {
                          'pet': widget.petId,
                          'vet': apptVetId,
                          'name': vaccineNameController.text.trim(),
                          'vaccineName': vaccineNameController.text.trim(),
                          'disease': vaccineNameController.text.trim(),
                          'dateAdministered': dateStr,
                          'date': dateStr,
                          'nextDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
                          'status': 'Đã tiêm',
                          'appointment': apptId,
                        };
                        
                        await BookingService().addVaccination(widget.user['token'], payload);
                        await BookingService().updateAppointmentStatus(widget.user['token'], apptId, 'hoàn_thành');
                        
                        // Thông báo khi hoàn thành tiêm phòng
                        final String ownerId = (appt['user'] is Map) ? (appt['user']['_id'] ?? appt['user']['id'])?.toString() ?? '' : ((appt['userId'] is Map) ? (appt['userId']['_id'] ?? appt['userId']['id'])?.toString() ?? '' : (appt['userId'] ?? appt['user'])?.toString() ?? '');
                        final petName = _pet?['name'] ?? ((appt['pet'] is Map) ? (appt['pet']['name'] ?? 'Thú cưng') : 'Thú cưng');
                        if (ownerId.isNotEmpty) {
                          try {
                            await BookingService().sendPushNotification(
                              token: widget.user['token'],
                              userId: ownerId,
                              title: 'Đã hoàn tất tiêm phòng',
                              body: 'Bác sĩ đã cập nhật mũi tiêm cho bé $petName.',
                              data: {'appointmentId': apptId.toString(), 'status': 'hoàn_thành'},
                            );
                          } catch (_) {}
                        }

                        if (!mounted) return;
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu kết quả tiêm phòng')));
                        
                        setState(() => _isLoadingAppointments = true);
                        _fetchAppointments();
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF07E2B),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Lưu kết quả'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedicalForm(dynamic appt) {
    final TextEditingController generalAssessmentController = TextEditingController();
    final TextEditingController consultationController = TextEditingController();
    final TextEditingController weightController = TextEditingController();
    final TextEditingController tempController = TextEditingController();
    List<String> selectedImagePaths = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nh\u1eadp k\u1ebft qu\u1ea3 kh\u00e1m b\u1ec7nh', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
                  const SizedBox(height: 20),
                  Text('\u0110\u00e1nh gi\u00e1 chung', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: generalAssessmentController,
                    decoration: InputDecoration(
                      hintText: 'Nh\u1eadp \u0111\u00e1nh gi\u00e1 chung...',
                      hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('T\u01b0 v\u1ea5n', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: consultationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nh\u1eadp t\u01b0 v\u1ea5n / ghi ch\u00fa...',
                      hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('C\u00e2n n\u1eb7ng (kg)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            TextField(
                              controller: weightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'VD: 5.2',
                                hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nhi\u1ec7t \u0111\u1ed9 (\u00b0C)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            TextField(
                              controller: tempController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'VD: 38.5',
                                hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('H\u00ecnh \u1ea3nh (k\u1ebft qu\u1ea3 X-quang, si\u00eau \u00e2m,...)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...selectedImagePaths.map((path) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(path), width: 60, height: 60, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                  onPressed: () => setLocalState(() => selectedImagePaths.remove(path)),
                                ),
                              ),
                            ],
                          )),
                      InkWell(
                        onTap: () async {
                          final picker = ImagePicker();
                          final pickedFiles = await picker.pickMultiImage();
                          if (pickedFiles.isNotEmpty) {
                            setLocalState(() => selectedImagePaths.addAll(pickedFiles.map((e) => e.path)));
                          }
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('H\u1ee7y', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                  if (generalAssessmentController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui l\u00f2ng nh\u1eadp \u0111\u00e1nh gi\u00e1 chung')));
                    return;
                  }
                  Navigator.pop(ctx); // \u0110\u00f3ng form ngay l\u1eadp t\u1ee9c

                  final apptId = appt['_id'] ?? appt['id'];
                  final apptVetId = (appt['vet'] is Map) ? (appt['vet']['_id'] ?? appt['vet']['id']) : (appt['vet'] ?? widget.user['id']);
                  final apptServiceId = (appt['service'] is Map) ? (appt['service']['_id'] ?? appt['service']['id']) : appt['service'];
                  final payload = {
                    'pet': widget.petId,
                    'vet': apptVetId,
                    'service': apptServiceId,
                    'appointment': apptId,
                    'generalAssessment': generalAssessmentController.text.trim(),
                    'consultation': consultationController.text.trim(),
                    'weight': weightController.text.trim().isEmpty ? null : double.tryParse(weightController.text.trim()),
                    'temperature': tempController.text.trim().isEmpty ? null : double.tryParse(tempController.text.trim()),
                    'examinationDate': DateTime.now().toIso8601String(),
                  };
                  final snappedPaths = List<String>.from(selectedImagePaths);

                  // Xoa khoi upcoming bang ID, tranh loi tham chieu
                  final apptIdStr = apptId?.toString();
                  setState(() {
                    _upcomingAppointments.removeWhere((a) => (a['_id'] ?? a['id'])?.toString() == apptIdStr);
                  });

                  // Goi API o background - fix status string
                  Future.wait([
                    BookingService().addHealthRecord(widget.user['token'], payload, imagePaths: snappedPaths),
                    BookingService().updateAppointmentStatus(widget.user['token'], apptId, 'ho\u00e0n_th\u00e0nh'),
                  ]).then((results) async {
                    // Thông báo khám bệnh hoàn thành
                    final String ownerId = (appt['user'] is Map) ? (appt['user']['_id'] ?? appt['user']['id'])?.toString() ?? '' : ((appt['userId'] is Map) ? (appt['userId']['_id'] ?? appt['userId']['id'])?.toString() ?? '' : (appt['userId'] ?? appt['user'])?.toString() ?? '');
                    final petName = _pet?['name'] ?? ((appt['pet'] is Map) ? (appt['pet']['name'] ?? 'Thú cưng') : 'Thú cưng');
                    if (ownerId.isNotEmpty) {
                      try {
                        await BookingService().sendPushNotification(
                          token: widget.user['token'],
                          userId: ownerId,
                          title: 'Đã có kết quả khám',
                          body: 'Bác sĩ đã cập nhật kết quả khám của bé $petName.',
                          data: {'appointmentId': apptId.toString(), 'status': 'hoàn_thành'},
                        );
                      } catch (_) {}
                    }

                    if (!mounted) return;
                    final newHrId = results[0] as String?;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('\u2713 \u0110\u00e3 l\u01b0u k\u1ebft qu\u1ea3 kh\u00e1m b\u1ec7nh')),
                    );
                    // Reload danh sach de dong bo
                    setState(() => _isLoadingAppointments = true);
                    _fetchAppointments().then((_) {
                      if (!mounted) return;
                      // Hien ket qua ngay sau khi reload
                      final hrId = newHrId ?? _apptToHealthRecord[apptIdStr];
                      if (hrId != null) _showHealthRecordDetails(hrId);
                    });
                  }).catchError((e) {
                    // Revert: hien lai trong upcoming
                    if (!mounted) return;
                    setState(() => _isLoadingAppointments = true);
                    _fetchAppointments();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('L\u1ed7i: ')));
                  });
                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF07E2B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('L\u01b0u k\u1ebft qu\u1ea3'),
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

