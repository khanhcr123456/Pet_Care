import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care/services/booking_service.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/screens/pets_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? initialPetId;
  final String? initialServiceId;
  final String? initialVetId;

  const BookingScreen({super.key, required this.user, this.initialPetId, this.initialServiceId, this.initialVetId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  Map<String, String>? _selectedTimeSlot;
  String? _selectedPetId;
  String? _selectedServiceId;
  String? _selectedVetId;
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<dynamic> _pets = [];
  List<dynamic> _services = [];
  List<dynamic> _vets = [];
  List<Map<String, String>> _timeSlots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.initialPetId;
    _selectedServiceId = widget.initialServiceId;
    _selectedVetId = widget.initialVetId;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        PetService().getPets(widget.user['token']),
        PetService().getServices(),
        AuthService().getVets(limit: 50),
      ]);
      
      final pets = results[0];
      final services = results[1];
      final vets = results[2];
      
      if (mounted) {
        setState(() {
          _pets = pets as List<dynamic>;
          _services = services as List<dynamic>;
          _vets = vets as List<dynamic>;
          _isLoading = false;
          
          if (_selectedPetId != null && !_pets.any((p) => p['_id'] == _selectedPetId)) {
            _selectedPetId = null;
          }
          if (_selectedServiceId != null && !_services.any((s) => s['_id'] == _selectedServiceId)) {
            _selectedServiceId = null;
          }
          if (_selectedVetId != null && !_vets.any((v) => v['_id'] == _selectedVetId)) {
            _selectedVetId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedPetId == null || _selectedServiceId == null || _selectedVetId == null || _selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đầy đủ thú cưng, dịch vụ, bác sĩ, ngày và giờ!')));
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final appointmentData = {
        'pet': _selectedPetId,
        'service': _selectedServiceId,
        'vet': _selectedVetId,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'timeSlot': {
          'startTime': _selectedTimeSlot!['startTime'],
          'endTime': _selectedTimeSlot!['endTime'],
        },
        'appointmentType': 'in_person',
        'status': 'pending'
      };

      await BookingService().bookAppointment(widget.user['token'], appointmentData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đặt lịch khám thành công!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _fetchAvailableSlots() async {
    if (_selectedVetId == null || _selectedDate == null) {
      if (mounted) {
        setState(() => _timeSlots = []);
      }
      return;
    }
    setState(() => _isLoadingSlots = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final slots = await BookingService().getAvailableSlots(widget.user['token'], _selectedVetId!, dateStr);
      if (mounted) {
        setState(() {
          _timeSlots = slots;
          _isLoadingSlots = false;
          if (_selectedTimeSlot != null && !_timeSlots.any((s) => s['startTime'] == _selectedTimeSlot!['startTime'])) {
            _selectedTimeSlot = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF07E2B), 
              onPrimary: Colors.white, 
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchAvailableSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = R.hPad(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(
          'Đặt lịch khám',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading 
        ? Padding(
            padding: EdgeInsets.all(hPad + 4),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 20, width: 150, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)),
                          Container(height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                        ],
                      ),
                    ),
                  Container(height: 54, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ],
              ),
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(hPad + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1. Chọn thú cưng'),
                if (_pets.isEmpty)
                  Container(
                    padding: EdgeInsets.all(hPad),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF07E2B).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pets, color: const Color(0xFFF07E2B), size: R.iconSm(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bạn chưa có hồ sơ thú cưng nào. Vui lòng thêm thú cưng để tiếp tục đặt lịch hẹn.',
                                style: TextStyle(color: const Color(0xFF0F2E53), fontSize: R.sp(context, 13)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => PetsScreen(user: widget.user, initialShowRegistration: true)),
                              ).then((result) {
                                if (result != null && result is String) {
                                  _selectedPetId = result;
                                }
                                setState(() => _isLoading = true);
                                _fetchData();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF07E2B),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 11 : 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Thêm thú cưng ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDropdown(
                        'Chọn thú cưng của bạn',
                        _selectedPetId,
                        _pets.map((p) => DropdownMenuItem<String>(
                          value: p['_id'],
                          child: Text(p['name'] ?? 'Không tên', style: TextStyle(fontSize: R.sp(context, 14))),
                        )).toList(),
                        (val) => setState(() => _selectedPetId = val),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PetsScreen(user: widget.user, initialShowRegistration: true)),
                            ).then((result) {
                              if (result != null && result is String) {
                                _selectedPetId = result;
                              }
                              setState(() => _isLoading = true);
                              _fetchData();
                            });
                          },
                          icon: Icon(Icons.add_circle_outline, size: R.iconSm(context) - 2),
                          label: Text('Thêm thú cưng mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13))),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF07E2B),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: R.isSmall(context) ? 18 : 24),
                _buildSectionTitle('2. Chọn dịch vụ'),
                _buildDropdown(
                  'Chọn dịch vụ cần khám',
                  _selectedServiceId,
                  _services.map((s) => DropdownMenuItem<String>(
                    value: s['_id'],
                    child: Text(s['name'] ?? 'Dịch vụ', style: TextStyle(fontSize: R.sp(context, 14))),
                  )).toList(),
                  (val) => setState(() => _selectedServiceId = val),
                ),
                
                SizedBox(height: R.isSmall(context) ? 18 : 24),
                _buildSectionTitle('3. Chọn bác sĩ'),
                _buildDropdown(
                  'Chọn bác sĩ',
                  _selectedVetId,
                  _vets.map((v) => DropdownMenuItem<String>(
                    value: v['_id'] ?? v['id'],
                    child: Text(v['fullName'] ?? v['name'] ?? 'Bác sĩ', style: TextStyle(fontSize: R.sp(context, 14))),
                  )).toList(),
                  (val) {
                    setState(() => _selectedVetId = val);
                    _fetchAvailableSlots();
                  },
                ),
                
                SizedBox(height: R.isSmall(context) ? 18 : 24),
                _buildSectionTitle('4. Chọn ngày & giờ'),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: R.isSmall(context) ? 13 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD9E8F5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null ? 'Chọn ngày khám' : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null ? Colors.grey : const Color(0xFF0F2E53),
                            fontSize: R.sp(context, 15),
                          ),
                        ),
                        Icon(Icons.calendar_today, color: const Color(0xFFF07E2B), size: R.iconSm(context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedVetId == null || _selectedDate == null)
                  Text('Vui lòng chọn bác sĩ và ngày khám để xem giờ trống.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: R.sp(context, 13)))
                else if (_isLoadingSlots)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                      4,
                      (index) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade50,
                        child: Container(
                          width: 80,
                          height: 40,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  )
                else if (_timeSlots.isEmpty)
                  Text('Không có giờ khám nào trống trong ngày này.', style: TextStyle(color: Colors.redAccent, fontSize: R.sp(context, 13)))
                else
                  Wrap(
                    spacing: R.isSmall(context) ? 8 : 10,
                    runSpacing: R.isSmall(context) ? 8 : 10,
                    children: _timeSlots.map((timeSlot) {
                      final isSelected = _selectedTimeSlot != null && _selectedTimeSlot!['startTime'] == timeSlot['startTime'];
                      final timeStr = timeSlot['startTime']!;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTimeSlot = timeSlot),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: R.isSmall(context) ? 12 : 16,
                            vertical: R.isSmall(context) ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF07E2B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? const Color(0xFFF07E2B) : const Color(0xFFD9E8F5)),
                          ),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF0F2E53),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: R.sp(context, 13),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                SizedBox(height: R.isSmall(context) ? 28 : 40),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, R.isSmall(context) ? 48 : 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('XÁC NHẬN ĐẶT LỊCH', style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: R.sp(context, 15),
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F2E53),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, String? value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E8F5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14))),
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
