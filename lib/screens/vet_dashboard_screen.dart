import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_care/screens/profile_screen.dart';
import 'package:pet_care/services/booking_service.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/screens/pet_detail_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';


class VetDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  
  const VetDashboardScreen({super.key, this.user});

  @override
  State<VetDashboardScreen> createState() => _VetDashboardScreenState();
}

class _VetDashboardScreenState extends State<VetDashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentUser;
  List<dynamic> _appointments = [];
  Map<String, String> _servicesMap = {};
  bool _isLoading = true;
  List<dynamic> _allPets = [];
  bool _isLoadingPets = true;
  bool _hasFetchedPets = false;
  
  DateTime _currentMonthSchedule = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedScheduleDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _fetchCurrentUser();
    _fetchAppointments();
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
      print('Error fetching vet profile: $e');
    }
  }

  Future<void> _fetchAllPets() async {
    if (_currentUser == null || _currentUser!['token'] == null) return;
    try {
      final pets = await PetService().getAllPets(_currentUser!['token']);
      if (mounted) {
        setState(() {
          _allPets = pets;
          _isLoadingPets = false;
          _hasFetchedPets = true;
        });
      }
    } catch (e) {
      print('Error fetching all pets: $e');
      if (mounted) {
        setState(() => _isLoadingPets = false);
      }
    }
  }

  Future<void> _fetchAppointments() async {
    if (_currentUser == null || _currentUser!['token'] == null) return;
    try {
      final vetId = _currentUser!['_id'] ?? _currentUser!['id'] ?? _currentUser!['user']?['_id'] ?? _currentUser!['user']?['id'];
      print('DEBUG VET ID: $vetId');
      
      final results = await Future.wait([
        BookingService().getVetAppointments(_currentUser!['token']),
        PetService().getServices(limit: 100),
      ]);
      
      final apps = results[0] as List<dynamic>;
      final services = results[1] as List<dynamic>;
      final cache = <String, String>{};
      for (var s in services) {
        if (s['_id'] != null) cache[s['_id'].toString()] = s['name']?.toString() ?? 'Dịch vụ';
        if (s['id'] != null) cache[s['id'].toString()] = s['name']?.toString() ?? 'Dịch vụ';
      }

      if (mounted) {
        setState(() {
          _appointments = apps;
          _servicesMap = cache;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.grid_view},
    {'title': 'Quản lý lịch hẹn', 'icon': Icons.calendar_month},
    {'title': 'Hồ sơ thú cưng', 'icon': Icons.pets},
    {'title': 'Lịch làm việc', 'icon': Icons.access_time},
    {'title': 'Tài khoản', 'icon': Icons.person},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.medical_services, color: Color(0xFFF07E2B), size: 28),
            SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: R.sp(context, 22), fontWeight: FontWeight.bold),
                children: const [
                  TextSpan(text: 'Pet', style: TextStyle(color: Color(0xFF0F2E53))),
                  TextSpan(text: 'Care', style: TextStyle(color: Color(0xFFF07E2B))),
                  TextSpan(text: ' Clinic', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
        ],
      ),
      body: _buildContentForIndex(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2 && !_hasFetchedPets) {
            _fetchAllPets();
          }
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF07E2B),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 12)),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: R.sp(context, 12)),
        items: [
          BottomNavigationBarItem(icon: Icon(_menuItems[0]['icon']), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(_menuItems[1]['icon']), label: 'Lịch hẹn'),
          BottomNavigationBarItem(icon: Icon(_menuItems[2]['icon']), label: 'Thú cưng'),
          BottomNavigationBarItem(icon: Icon(_menuItems[3]['icon']), label: 'Lịch làm'),
          BottomNavigationBarItem(icon: Icon(_menuItems[4]['icon']), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    if (index == 0) {
      return _buildDashboard();
    }
    if (index == 1) {
      return _buildAppointmentsList();
    }
    if (index == 2) {
      return _buildAllPetsList();
    }
    if (index == 3) {
      return _buildSchedule();
    }
    if (index == 4) {
      return ProfileScreen(
        user: _currentUser,
        onUserUpdated: (updatedUser) {
          setState(() {
            _currentUser = updatedUser;
          });
        },
      );
    }

    // Add title banner before content for other tabs
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 12),
          color: const Color(0xFFF5F6FA),
          child: Text(
            _menuItems[index]['title'],
            style: TextStyle(
              fontSize: R.sp(context, 18),
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2E53),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_menuItems[index]['title']} Content',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedule() {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonthSchedule.year, _currentMonthSchedule.month);
    final firstDayOffset = _currentMonthSchedule.weekday % 7; // Sunday=0, Monday=1...

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedScheduleDate);
    final dayApps = _appointments.where((a) {
      if (a['date'] == null) return false;
      final aDate = DateTime.tryParse(a['date'].toString());
      if (aDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(aDate) == dateStr;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
        // Custom Calendar
        Container(
          margin: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
          padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _currentMonthSchedule = DateTime(_currentMonthSchedule.year, _currentMonthSchedule.month - 1, 1);
                      });
                    },
                  ),
                  Text('Tháng ${_currentMonthSchedule.month} ${_currentMonthSchedule.year}', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _currentMonthSchedule = DateTime(_currentMonthSchedule.year, _currentMonthSchedule.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                    .map((d) => Expanded(
                          child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: R.isSmall(context) ? 0.6 : 0.8,
                ),
                itemCount: 42,
                itemBuilder: (ctx, i) {
                  final day = i - firstDayOffset + 1;
                  if (day < 1 || day > daysInMonth) return const SizedBox();

                  final cellDate = DateTime(_currentMonthSchedule.year, _currentMonthSchedule.month, day);
                  final isSelected = DateFormat('yyyy-MM-dd').format(cellDate) == DateFormat('yyyy-MM-dd').format(_selectedScheduleDate);
                  
                  final cellDateStr = DateFormat('yyyy-MM-dd').format(cellDate);
                  final appCount = _appointments.where((a) {
                    if (a['date'] == null) return false;
                    final aDate = DateTime.tryParse(a['date'].toString());
                    if (aDate == null) return false;
                    return DateFormat('yyyy-MM-dd').format(aDate) == cellDateStr;
                  }).length;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedScheduleDate = cellDate;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFF8F0) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F2E53) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (appCount > 0) ...[
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('$appCount lịch', style: TextStyle(fontSize: R.sp(context, 9), color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Day list
        Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selectedScheduleDate.day}/${_selectedScheduleDate.month}/${_selectedScheduleDate.year}', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                Text('${dayApps.length} lịch hẹn', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                dayApps.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Không có lịch hẹn', style: TextStyle(color: Colors.grey))))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dayApps.length,
                        itemBuilder: (ctx, i) {
                            final app = dayApps[i];
                            final petName = (app['pet'] is Map) ? (app['pet']['name'] ?? 'Thú cưng') : ((app['petId'] is Map) ? (app['petId']['name'] ?? 'Thú cưng') : 'Thú cưng');
                            final serviceName = (app['service'] is Map) ? (app['service']['name'] ?? 'Dịch vụ') : (_servicesMap[app['service']?.toString()] ?? app['service']?.toString() ?? 'Dịch vụ');
                            
                            String startTime = '';
                            if (app['timeSlot'] != null && app['timeSlot'] is Map) {
                              startTime = app['timeSlot']['startTime'] ?? '';
                            } else {
                              startTime = app['startTime'] ?? app['time'] ?? '';
                            }
                            if (startTime.contains('T')) {
                              final parts = startTime.split('T');
                              if (parts.length > 1 && parts[1].length >= 5) {
                                startTime = parts[1].substring(0, 5);
                              }
                            } else if (startTime.length > 5) {
                              startTime = startTime.substring(0, 5);
                            }
                            
                            final statusStr = app['status']?.toString().toLowerCase() ?? 'chờ_xác_nhận';
                            String statusDisplay = 'Chờ xác nhận';
                            if (statusStr == 'đã_xác_nhận') statusDisplay = 'Đã xác nhận';
                            else if (statusStr == 'đang_khám') statusDisplay = 'Đang khám';
                            else if (statusStr == 'hoàn_thành') statusDisplay = 'Hoàn thành';
                            else if (statusStr == 'đã_hủy') statusDisplay = 'Đã hủy';

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(startTime.isNotEmpty ? startTime : '--:--', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: R.sp(context, 13))),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: statusDisplay == 'Hoàn thành' ? Colors.green.shade50 : (statusDisplay == 'Đã xác nhận' ? Colors.blue.shade50 : (statusDisplay == 'Đang khám' ? Colors.purple.shade50 : (statusDisplay == 'Đã hủy' ? Colors.red.shade50 : Colors.orange.shade50))),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(petName, style: TextStyle(fontWeight: FontWeight.bold, color: statusDisplay == 'Hoàn thành' ? Colors.green.shade800 : Colors.blue.shade900)),
                                          Text(serviceName, style: TextStyle(fontSize: R.sp(context, 12), color: Colors.black54)),
                                          Text(statusDisplay, style: TextStyle(fontSize: R.sp(context, 11), color: Colors.black38)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final docName = _currentUser?['fullName'] ?? _currentUser?['name'] ?? 'Bác sĩ';
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(R.hPad(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, $docName 👋',
            style: TextStyle(
              fontSize: R.sp(context, 24),
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2E53),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Chúc bạn một ngày làm việc hiệu quả!',
            style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14)),
          ),
          SizedBox(height: 24),
          
          // Stats Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildStatCard('Lịch hôm nay', _getTodayCount().toString(), Icons.calendar_today, const Color(0xFF4CA1AF))),
                SizedBox(width: 8),
                Expanded(child: _buildStatCard('Đang chờ', _getPendingCount().toString(), Icons.hourglass_empty, const Color(0xFFF07E2B))),
                SizedBox(width: 8),
                Expanded(child: _buildStatCard('Hoàn thành', _getCompletedCount().toString(), Icons.check_circle_outline, const Color(0xFF43A047))),
              ],
            ),
          ),
          
          SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch hẹn hôm nay',
                style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: Color(0xFF0F2E53)),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFFF07E2B))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_isLoading)
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Column(
                children: List.generate(3, (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                )),
              ),
            )
          else if (_getTodayAppointments().isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('Không có lịch hẹn hôm nay.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ..._getTodayAppointments().map((app) {
              String startTime = '';
              String endTime = '';
              if (app['timeSlot'] != null && app['timeSlot'] is Map) {
                startTime = app['timeSlot']['startTime'] ?? '';
                endTime = app['timeSlot']['endTime'] ?? '';
              } else {
                startTime = app['startTime'] ?? '';
                endTime = app['endTime'] ?? '';
              }
              final String time = endTime.isNotEmpty ? '$startTime - $endTime' : startTime;
              
              final petName = (app['pet'] is Map) ? (app['pet']['name'] ?? 'Thú cưng') : ((app['petId'] is Map) ? (app['petId']['name'] ?? 'Thú cưng') : 'Thú cưng');
              final serviceName = (app['service'] is Map) ? (app['service']['name'] ?? 'Dịch vụ') : (_servicesMap[app['service']?.toString()] ?? app['service']?.toString() ?? 'Dịch vụ');
              
              final String status = app['status']?.toString().toLowerCase() ?? 'chờ_xác_nhận';
              String statusDisplay = 'Chờ xác nhận';
              if (status == 'đã_xác_nhận') statusDisplay = 'Đã xác nhận';
              else if (status == 'đang_khám') statusDisplay = 'Đang khám';
              else if (status == 'hoàn_thành') statusDisplay = 'Hoàn thành';
              else if (status == 'đã_hủy') statusDisplay = 'Đã hủy';
              
              final petId = (app['pet'] is Map) ? (app['pet']['_id'] ?? app['pet']['id']) : ((app['petId'] is Map) ? (app['petId']['_id'] ?? app['petId']['id']) : (app['petId'] ?? app['pet']));
              final ownerName = (app['user'] is Map) ? (app['user']['fullName'] ?? app['user']['name'] ?? 'Khách hàng') : ((app['userId'] is Map) ? (app['userId']['fullName'] ?? app['userId']['name'] ?? 'Khách hàng') : 'Khách hàng');
              
              return _buildUpcomingAppointmentCard(time, petName, ownerName, serviceName, statusDisplay, app['date'], petId?.toString());
            }),
        ],
      ),
    );
  }

  int _getTodayCount() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _appointments.where((a) {
      if (a['date'] == null) return false;
      final aDate = DateTime.tryParse(a['date'].toString());
      if (aDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(aDate) == todayStr;
    }).length;
  }

  int _getPendingCount() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _appointments.where((a) {
      if (a['date'] == null || a['status'] != 'chờ_xác_nhận') return false;
      final aDate = DateTime.tryParse(a['date'].toString());
      if (aDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(aDate) == todayStr;
    }).length;
  }

  int _getCompletedCount() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _appointments.where((a) {
      if (a['date'] == null || a['status'] != 'hoàn_thành') return false;
      final aDate = DateTime.tryParse(a['date'].toString());
      if (aDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(aDate) == todayStr;
    }).length;
  }

  List<dynamic> _getTodayAppointments() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayApps = _appointments.where((a) {
      if (a['date'] == null) return false;
      final aDate = DateTime.tryParse(a['date'].toString());
      if (aDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(aDate) == todayStr;
    }).toList();
    
    todayApps.sort((a, b) {
      final aDate = DateTime.tryParse(a['date'].toString()) ?? DateTime.now();
      final bDate = DateTime.tryParse(b['date'].toString()) ?? DateTime.now();
      return aDate.compareTo(bDate);
    });
    
    return todayApps;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: R.sp(context, 24)),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: R.sp(context, 20), fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: R.sp(context, 11), color: Colors.grey, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentCard(String time, String petName, String ownerName, String service, String status, dynamic dateStr, String? petId) {
    String dateDisplay = '';
    if (dateStr != null) {
      final d = DateTime.tryParse(dateStr.toString());
      if (d != null) dateDisplay = DateFormat('dd/MM/yyyy').format(d);
    }
    
    return GestureDetector(
      onTap: () {
        if (petId != null && _currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetDetailScreen(
                petId: petId,
                user: _currentUser!,
              ),
            ),
          ).then((_) {
            setState(() => _isLoading = true);
            _fetchAppointments();
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.isSmall(context) ? 8 : 12, vertical: R.isSmall(context) ? 6 : 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                ),
                if (dateDisplay.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    dateDisplay,
                    style: TextStyle(color: const Color(0xFFF07E2B), fontSize: R.sp(context, 11)),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: R.isSmall(context) ? 8 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(petName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: Color(0xFF0F2E53)))),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: R.isSmall(context) ? 6 : 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Hoàn thành' ? Colors.green.shade50 : (status == 'Đã xác nhận' ? Colors.blue.shade50 : (status == 'Đang khám' ? Colors.purple.shade50 : (status == 'Đã hủy' ? Colors.red.shade50 : Colors.orange.shade50))),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'Hoàn thành' ? Colors.green.shade700 : (status == 'Đã xác nhận' ? Colors.blue.shade700 : (status == 'Đang khám' ? Colors.purple.shade700 : (status == 'Đã hủy' ? Colors.red.shade700 : Colors.orange.shade700))), 
                          fontSize: R.sp(context, 11), 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ]
                ),
                SizedBox(height: 4),
                Text('Chủ nuôi: $ownerName', style: TextStyle(color: Colors.grey.shade700, fontSize: R.sp(context, 13))),
                SizedBox(height: 2),
                Text(service, style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final sortedApps = List.from(_appointments);
    sortedApps.sort((a, b) {
      DateTime aDate = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
      DateTime bDate = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
      
      String aTime = '';
      if (a['timeSlot'] != null && a['timeSlot'] is Map) {
        aTime = a['timeSlot']['startTime'] ?? '';
      } else {
        aTime = a['startTime'] ?? '';
      }
      String bTime = '';
      if (b['timeSlot'] != null && b['timeSlot'] is Map) {
        bTime = b['timeSlot']['startTime'] ?? '';
      } else {
        bTime = b['startTime'] ?? '';
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
      
      return bDate.compareTo(aDate); // newest first
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 16),
          color: const Color(0xFFF5F6FA),
          child: Text(
            'Quản lý lịch hẹn',
            style: TextStyle(
              fontSize: R.sp(context, 20),
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2E53),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                  itemCount: 5,
                  itemBuilder: (_, __) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade50,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAppointments,
                  color: const Color(0xFFF07E2B),
                  child: _appointments.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: 100),
                            Center(
                              child: Text('Chưa có lịch hẹn nào.', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 16))),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                          itemCount: sortedApps.length,
                          itemBuilder: (context, i) {
                            final app = sortedApps[i];
                            
                            String startTime = '';
                            String endTime = '';
                            if (app['timeSlot'] != null && app['timeSlot'] is Map) {
                              startTime = app['timeSlot']['startTime'] ?? '';
                              endTime = app['timeSlot']['endTime'] ?? '';
                            } else {
                              startTime = app['startTime'] ?? '';
                              endTime = app['endTime'] ?? '';
                            }
                            final String time = endTime.isNotEmpty ? '$startTime - $endTime' : startTime;
                            
                            String dateDisplay = '';
                            if (app['date'] != null) {
                              final d = DateTime.tryParse(app['date'].toString());
                              if (d != null) dateDisplay = DateFormat('dd/MM/yyyy').format(d);
                            }
                            
                            final petName = (app['pet'] is Map) ? (app['pet']['name'] ?? 'Thú cưng') : ((app['petId'] is Map) ? (app['petId']['name'] ?? 'Thú cưng') : 'Thú cưng');
                            final ownerName = (app['user'] is Map) ? (app['user']['fullName'] ?? app['user']['name'] ?? 'Khách hàng') : ((app['userId'] is Map) ? (app['userId']['fullName'] ?? app['userId']['name'] ?? 'Khách hàng') : 'Khách hàng');
                            final serviceName = (app['service'] is Map) ? (app['service']['name'] ?? 'Dịch vụ') : (_servicesMap[app['service']?.toString()] ?? app['service']?.toString() ?? 'Dịch vụ');
                            
                            final String status = app['status']?.toString().toLowerCase() ?? 'chờ_xác_nhận';
                            String statusDisplay = 'Chờ xác nhận';
                            if (status == 'đã_xác_nhận') statusDisplay = 'Đã xác nhận';
                            else if (status == 'đang_khám') statusDisplay = 'Đang khám';
                            else if (status == 'hoàn_thành') statusDisplay = 'Hoàn thành';
                            else if (status == 'đã_hủy') statusDisplay = 'Đã hủy';
                            
                            final petId = (app['pet'] is Map) ? (app['pet']['_id'] ?? app['pet']['id']) : ((app['petId'] is Map) ? (app['petId']['_id'] ?? app['petId']['id']) : (app['petId'] ?? app['pet']));
                            
                            return _buildDetailAppointmentCard(
                              appt: app,
                              time: '$time, $dateDisplay',
                              petName: petName,
                              ownerName: ownerName,
                              serviceName: serviceName,
                              statusDisplay: statusDisplay,
                              petId: petId?.toString(),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildDetailAppointmentCard({
    required dynamic appt,
    required String time,
    required String petName,
    required String ownerName,
    required String serviceName,
    required String statusDisplay,
    String? petId,
  }) {
    Color statusColor = Colors.orange.shade700;
    Color statusBgColor = Colors.orange.shade50;
    
    if (statusDisplay == 'Hoàn thành') {
      statusColor = Colors.green.shade700;
      statusBgColor = Colors.green.shade50;
    } else if (statusDisplay == 'Đã xác nhận') {
      statusColor = Colors.blue.shade700;
      statusBgColor = Colors.blue.shade50;
    } else if (statusDisplay == 'Đang khám') {
      statusColor = Colors.purple.shade700;
      statusBgColor = Colors.purple.shade50;
    } else if (statusDisplay == 'Đã hủy') {
      statusColor = Colors.red.shade700;
      statusBgColor = Colors.red.shade50;
    }

    return GestureDetector(
      onTap: () {
        if (petId != null && _currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetDetailScreen(
                petId: petId,
                user: _currentUser!,
              ),
            ),
          ).then((_) {
            setState(() => _isLoading = true);
            _fetchAppointments();
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header (Status)
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 12),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trạng thái', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.black54, fontWeight: FontWeight.bold)),
                Text(
                  statusDisplay,
                  style: TextStyle(color: statusColor, fontSize: R.sp(context, 13), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Details
          Padding(
            padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
            child: Column(
              children: [
                _buildInfoRow(Icons.pets, 'Thú cưng', petName),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _buildInfoRow(Icons.person_outline, 'Chủ nuôi', ownerName),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _buildInfoRow(Icons.access_time, 'Thời gian', time),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _buildInfoRow(Icons.medical_services_outlined, 'Dịch vụ', serviceName, isLast: true),
                
                if (statusDisplay != 'Hoàn thành' && statusDisplay != 'Đã hủy') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () async {
                        String newStatus = '';
                        String status = appt['status']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'chờ_xác_nhận';
                        bool isVaccine = serviceName.toLowerCase().contains('tiêm') || serviceName.toLowerCase().contains('vaccine');

                        if (status == 'chờ_xác_nhận' || status == 'pending') newStatus = 'đã_xác_nhận';
                        else if (status == 'đã_xác_nhận' || status == 'confirmed') newStatus = 'đang_khám';
                        else if (status == 'đang_khám' || status == 'in_progress') {
                          if (isVaccine) {
                            _showVaccinationForm(appt, petId);
                          } else {
                            _showMedicalForm(appt, petId);
                          }
                          return;
                        }
                        
                        if (newStatus.isEmpty) return;
                        
                        try {
                          final apptId = appt['_id'] ?? appt['id'];
                          await BookingService().updateAppointmentStatus(_currentUser!['token'], apptId, newStatus);
                          if (!mounted) return;
                          
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật trạng thái thành công')));
                          setState(() => _isLoading = true);
                          _fetchAppointments();
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
                        (statusDisplay == 'Chờ xác nhận') ? 'Xác nhận lịch hẹn' : ((statusDisplay == 'Đã xác nhận') ? (serviceName.toLowerCase().contains('tiêm') || serviceName.toLowerCase().contains('vaccine') ? 'Bắt đầu tiêm phòng' : 'Bắt đầu khám bệnh') : 'Nhập kết quả'),
                        style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (statusDisplay == 'Hoàn thành') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () async {
                        if (petId == null) return;
                        bool isVaccine = serviceName.toLowerCase().contains('tiêm') || serviceName.toLowerCase().contains('vaccine');
                        showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
                        try {
                          final apptId = appt['_id'] ?? appt['id'];
                          if (isVaccine) {
                            final vaxes = await BookingService().getVaccinationsByPetId(_currentUser!['token'], petId);
                            if (!mounted) return;
                            Navigator.pop(context); // close loading
                            final vax = vaxes.firstWhere((v) => (v['appointment'] is Map ? (v['appointment']['_id'] ?? v['appointment']['id']) : v['appointment']) == apptId, orElse: () => null);
                            if (vax != null) {
                              _showVaccinationDetails(vax);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy thông tin tiêm phòng')));
                            }
                          } else {
                            final records = await BookingService().getHealthRecordsByPetId(_currentUser!['token'], petId);
                            if (!mounted) return;
                            Navigator.pop(context); // close loading
                            final hr = records.firstWhere((hr) => (hr['appointment'] is Map ? (hr['appointment']['_id'] ?? hr['appointment']['id']) : hr['appointment']) == apptId, orElse: () => null);
                            if (hr != null) {
                              _showHealthRecordDetails(hr);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy kết quả khám bệnh')));
                            }
                          }
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0F4C81)),
                        foregroundColor: const Color(0xFF0F4C81),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        (serviceName.toLowerCase().contains('tiêm') || serviceName.toLowerCase().contains('vaccine')) ? 'Xem thông tin bản tiêm' : 'Xem kết quả',
                        style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F2E53).withOpacity(0.6)),
        SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: R.sp(context, 14),
              color: Color(0xFF0F2E53),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllPetsList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 16),
          color: const Color(0xFFF5F6FA),
          child: Text(
            'Hồ sơ thú cưng',
            style: TextStyle(
              fontSize: R.sp(context, 20),
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2E53),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingPets
              ? Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
              : RefreshIndicator(
                  onRefresh: _fetchAllPets,
                  color: const Color(0xFFF07E2B),
                  child: _allPets.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: 100),
                            Center(
                              child: Text('Không có hồ sơ thú cưng nào.', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 16))),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                          itemCount: _allPets.length,
                          itemBuilder: (context, index) {
                            final pet = _allPets[index];
                            final name = pet['name'] ?? 'Thú cưng';
                            final breed = pet['breed'] ?? 'Không rõ giống';
                            final ownerName = (pet['owner'] is Map) ? (pet['owner']['fullName'] ?? pet['owner']['name'] ?? 'Khách hàng') : ((pet['user'] is Map) ? (pet['user']['fullName'] ?? pet['user']['name'] ?? 'Khách hàng') : 'Khách hàng');
                            final avatarUrl = (pet['avatar'] != null && pet['avatar'].toString().startsWith('http')) ? pet['avatar'] : null;
                            final petId = pet['_id'] ?? pet['id'];

                            return GestureDetector(
                              onTap: () {
                                if (petId != null && _currentUser != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PetDetailScreen(
                                        petId: petId.toString(),
                                        user: _currentUser!,
                                      ),
                                    ),
                                  ).then((_) {
                                    // Refresh pets on return
                                    _fetchAllPets();
                                  });
                                }
                              },
                              child: Container(
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                                  child: Row(
                                    children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                      child: avatarUrl == null ? Icon(Icons.pets, color: Colors.grey, size: 30) : null,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16), color: Color(0xFF0F2E53))),
                                          SizedBox(height: 4),
                                          Text('Giống: $breed', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14))),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.person, size: 14, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Text('Chủ: $ownerName', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                                  ],
                                ),
                              ),
                             ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  void _showVaccinationForm(dynamic appt, String? petId) {
    if (petId == null) return;
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
                        final apptVetId = (appt['vet'] is Map) ? (appt['vet']['_id'] ?? appt['vet']['id']) : (appt['vet'] ?? _currentUser!['id'] ?? _currentUser!['_id']);
                        final dateStr = (appt['date'] != null && appt['date'] != '---') ? appt['date'] : DateTime.now().toIso8601String();
                        
                        final payload = {
                          'pet': petId,
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
                        
                        await BookingService().addVaccination(_currentUser!['token'], payload);
                        await BookingService().updateAppointmentStatus(_currentUser!['token'], apptId, 'hoàn_thành');
                        
                        if (!mounted) return;
                        Navigator.pop(context); // Close loading
                        
                        setState(() => _isLoading = true);
                        _fetchAppointments();
                        
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Thành công', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            content: const Text('Nhập kết quả thành công.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        );
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

  void _showMedicalForm(dynamic appt, String? petId) {
    if (petId == null) return;
    
    // Dynamically show dialog using form fields
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
        builder: (dialogContext, setLocalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nhập kết quả khám bệnh', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
                  const SizedBox(height: 20),
                  Text('Đánh giá chung', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: generalAssessmentController,
                    decoration: InputDecoration(
                      hintText: 'Nhập đánh giá chung...',
                      hintStyle: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Tư vấn', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: consultationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập tư vấn / ghi chú...',
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
                            Text('Cân nặng (kg)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
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
                            Text('Nhiệt độ (°C)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
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
                  Text('Hình ảnh (kết quả X-quang, siêu âm,...)', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
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
                        child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (generalAssessmentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đánh giá chung')));
                            return;
                          }
                          Navigator.pop(ctx); 

                          final apptId = appt['_id'] ?? appt['id'];
                          final apptVetId = (appt['vet'] is Map) ? (appt['vet']['_id'] ?? appt['vet']['id']) : (appt['vet'] ?? _currentUser!['id'] ?? _currentUser!['_id']);
                          final apptServiceId = (appt['service'] is Map) ? (appt['service']['_id'] ?? appt['service']['id']) : appt['service'];
                          final payload = {
                            'pet': petId,
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

                          Future.wait([
                            BookingService().addHealthRecord(_currentUser!['token'], payload, imagePaths: snappedPaths),
                            BookingService().updateAppointmentStatus(_currentUser!['token'], apptId, 'hoàn_thành'),
                          ]).then((results) {
                            if (!mounted) return;
                            setState(() => _isLoading = true);
                            _fetchAppointments();
                            
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Thành công', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                content: const Text('Nhập kết quả thành công.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Đóng'),
                                  ),
                                ],
                              ),
                            );
                          }).catchError((e) {
                            if (!mounted) return;
                            setState(() => _isLoading = true);
                            _fetchAppointments();
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                          });
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
          );
        },
      ),
    );
  }

  void _showHealthRecordDetails(dynamic hrData) {
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
  }

  void _showVaccinationDetails(dynamic vaxData) {
      final vaxName = vaxData['vaccineName'] ?? vaxData['name'] ?? 'Không xác định';
      final status = vaxData['status'] ?? 'Đã tiêm';
      String dateAdmin = '';
      if (vaxData['dateAdministered'] != null) {
        final p = vaxData['dateAdministered'].toString().split('T')[0].split('-');
        if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
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
}
