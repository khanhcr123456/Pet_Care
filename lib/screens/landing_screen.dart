import 'package:flutter/material.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/screens/pets_screen.dart';
import 'package:pet_care/screens/profile_screen.dart';
import 'package:pet_care/screens/services_screen.dart';
import 'package:pet_care/screens/vets_screen.dart';
import 'package:pet_care/screens/appointments_screen.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:pet_care/screens/store_screen.dart';
import 'package:pet_care/screens/cart_screen.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';
import 'package:pet_care/services/auth_service.dart';

class LandingScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  
  const LandingScreen({super.key, this.user});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.pets, color: Color(0xFFF07E2B), size: 28),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'Paw', style: TextStyle(color: Color(0xFF0F2E53))),
                  TextSpan(text: 'Rent', style: TextStyle(color: Color(0xFFF07E2B))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => StoreScreen(user: _currentUser)));
            },
            icon: const Icon(Icons.storefront, color: Color(0xFF0F2E53)),
          ),
          IconButton(
            onPressed: () {
              if (_currentUser == null || _currentUser!['token'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để xem giỏ hàng!')));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(user: _currentUser!)));
            },
            icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0F2E53)),
          ),
          _currentUser != null 
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipOval(
                  child: Container(
                    width: 36,
                    height: 36,
                    color: Colors.grey[200],
                    child: (_currentUser!['avatar'] != null && _currentUser!['avatar'].toString().trim().isNotEmpty && _currentUser!['avatar'].toString().startsWith('http'))
                        ? Image.network(
                            _currentUser!['avatar'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset('assets/images/hero_pets.png', fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/hero_pets.png', fit: BoxFit.cover),
                  ),
                ),
              )
            : TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Đăng nhập', style: TextStyle(color: Color(0xFF0F2E53), fontWeight: FontWeight.bold)),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF07E2B),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: 'Dịch vụ'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Thú cưng'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch khám'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 1) {
      return ServicesScreen(user: _currentUser);
    }
    if (_selectedIndex == 2) {
      return PetsScreen(user: _currentUser);
    }
    if (_selectedIndex == 3) {
      if (_currentUser != null) {
        return AppointmentsScreen(user: _currentUser!, isEmbedded: true);
      } else {
        return const Center(child: Text('Vui lòng đăng nhập để xem lịch khám'));
      }
    }
    if (_selectedIndex == 4) {
      return ProfileScreen(
        user: _currentUser,
        onUserUpdated: (updatedUser) {
          setState(() {
            _currentUser = updatedUser;
          });
        },
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(),
          _buildFeaturesSection(),
          _buildDoctorsSection(),
          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF9E6),
            Color(0xFFFFD740),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          // Image on top for mobile
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/hero_pets.png',
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.3),
              children: [
                TextSpan(text: 'An Toàn Cho ', style: TextStyle(color: Color(0xFF1F2937))),
                TextSpan(text: '"Boss"\n', style: TextStyle(color: Color(0xFF0F2E53))),
                TextSpan(text: 'An Tâm Cho ', style: TextStyle(color: Color(0xFF1F2937))),
                TextSpan(text: '"Sen"', style: TextStyle(color: Color(0xFF0F2E53))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pawrent cung cấp dịch vụ chăm sóc thú cưng toàn diện với đội ngũ bác sĩ thú y chuyên nghiệp, 24/7 sẵn sàng đồng hành cùng thú cưng của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              if (_currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch hẹn!')));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BookingScreen(user: _currentUser!)),
              );
            },
            icon: const Icon(Icons.access_time, size: 20, color: Color(0xFF0F2E53)),
            label: const Text('Đặt lịch hẹn ngay', style: TextStyle(color: Color(0xFF0F2E53), fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFE566),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {'icon': Icons.pets, 'title': 'Dịch vụ thú cưng', 'color': Colors.orange},
      {'icon': Icons.book, 'title': 'Sổ điện tử', 'color': Colors.blue},
      {'icon': Icons.calendar_month, 'title': 'Đặt lịch khám', 'color': Colors.purple},
      {'icon': Icons.storefront, 'title': 'Cửa hàng thú cưng', 'color': Colors.pink},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text('Dịch Vụ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onTap: () {
                    if (f['title'] == 'Cửa hàng thú cưng') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => StoreScreen(user: _currentUser)));
                    } else if (f['title'] == 'Dịch vụ thú cưng') {
                      setState(() => _selectedIndex = 1);
                    } else if (f['title'] == 'Đặt lịch khám') {
                      if (_currentUser != null) {
                        setState(() => _selectedIndex = 3);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để xem lịch khám')));
                      }
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 65, height: 65,
                        decoration: BoxDecoration(
                          color: (f['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(f['icon'] as IconData, color: f['color'] as Color, size: 32),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          f['title'] as String, 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF07E2B).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF07E2B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Đội Ngũ Bác Sĩ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2E53))),
                  SizedBox(height: 4),
                  Text('Xem danh sách các chuyên gia thú y hàng đầu', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFF07E2B)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VetsScreen(user: _currentUser)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
