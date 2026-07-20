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
import 'package:pet_care/utils/responsive.dart';

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
            Icon(Icons.pets, color: const Color(0xFFF07E2B), size: R.iconMd(context)),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: R.sp(context, 20), fontWeight: FontWeight.bold),
                children: const [
                  TextSpan(text: 'Paw', style: TextStyle(color: Color(0xFF0F2E53))),
                  TextSpan(text: 'Rent', style: TextStyle(color: Color(0xFFF07E2B))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(user: _currentUser))),
            icon: const Icon(Icons.storefront, color: Color(0xFF0F2E53)),
            tooltip: 'Cửa hàng',
          ),
          IconButton(
            onPressed: () {
              if (_currentUser == null || _currentUser!['token'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để xem giỏ hàng!')));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(user: _currentUser!)));
            },
            icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0F2E53)),
            tooltip: 'Giỏ hàng',
          ),
          _currentUser != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 4),
                    child: ClipOval(
                      child: Container(
                        width: 34,
                        height: 34,
                        color: Colors.grey[200],
                        child: (_currentUser!['avatar'] != null &&
                                _currentUser!['avatar'].toString().trim().isNotEmpty &&
                                _currentUser!['avatar'].toString().startsWith('http'))
                            ? Image.network(
                                _currentUser!['avatar'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset('assets/images/hero_pets.png', fit: BoxFit.cover),
                              )
                            : Image.asset('assets/images/hero_pets.png', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: const Color(0xFF0F2E53),
                      fontWeight: FontWeight.bold,
                      fontSize: R.sp(context, 13),
                    ),
                  ),
                ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF07E2B),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontSize: R.sp(context, 11), fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: R.sp(context, 11)),
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
    return IndexedStack(
      index: _selectedIndex,
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(),
              _buildFeaturesSection(),
              _buildDoctorsSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
        ServicesScreen(user: _currentUser),
        PetsScreen(user: _currentUser),
        _currentUser != null
            ? AppointmentsScreen(user: _currentUser!, isEmbedded: true)
            : const Center(child: Text('Vui lòng đăng nhập để xem lịch khám')),
        ProfileScreen(
          user: _currentUser,
          onUserUpdated: (u) => setState(() => _currentUser = u),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF9E6), Color(0xFFFFD740)],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: R.hPad(context),
        vertical: R.isSmall(context) ? 20 : 28,
      ),
      child: Column(
        children: [
          // Hero image — height responsive
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/hero_pets.png',
              width: double.infinity,
              height: R.heroHeight(context),
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: R.isSmall(context) ? 20 : 28),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: R.sp(context, 28),
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
              children: const [
                TextSpan(text: 'An Toàn Cho ', style: TextStyle(color: Color(0xFF1F2937))),
                TextSpan(text: '"Boss"\n', style: TextStyle(color: Color(0xFF0F2E53))),
                TextSpan(text: 'An Tâm Cho ', style: TextStyle(color: Color(0xFF1F2937))),
                TextSpan(text: '"Sen"', style: TextStyle(color: Color(0xFF0F2E53))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'PetCare cung cấp dịch vụ chăm sóc thú cưng toàn diện với đội ngũ bác sĩ thú y chuyên nghiệp, 24/7 sẵn sàng đồng hành.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: R.sp(context, 14),
              height: 1.5,
              color: const Color(0xFF4B5563),
            ),
          ),
          SizedBox(height: R.isSmall(context) ? 20 : 28),
          ElevatedButton.icon(
            onPressed: () {
              if (_currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch hẹn!')));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(user: _currentUser!)));
            },
            icon: Icon(Icons.access_time, size: R.iconSm(context), color: const Color(0xFF0F2E53)),
            label: Text(
              'Đặt lịch hẹn ngay',
              style: TextStyle(
                color: const Color(0xFF0F2E53),
                fontSize: R.sp(context, 15),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFE566),
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: R.isSmall(context) ? 20 : 28,
                vertical: R.isSmall(context) ? 12 : 15,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
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

    final boxSize = R.isSmall(context) ? 58.0 : 65.0;
    final textWidth = R.isSmall(context) ? 72.0 : 82.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: R.hPad(context)),
            child: Text(
              'Dịch Vụ',
              style: TextStyle(
                fontSize: R.sp(context, 18),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F2E53),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: R.hPad(context) - 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features.map((f) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () {
                      final title = f['title'] as String;
                      if (title == 'Cửa hàng thú cưng') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(user: _currentUser)));
                      } else if (title == 'Dịch vụ thú cưng') {
                        setState(() => _selectedIndex = 1);
                      } else if (title == 'Đặt lịch khám') {
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
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: (f['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(f['icon'] as IconData, color: f['color'] as Color, size: R.isSmall(context) ? 28 : 32),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: textWidth,
                          child: Text(
                            f['title'] as String,
                            style: TextStyle(
                              fontSize: R.sp(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.hPad(context), vertical: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VetsScreen(user: _currentUser))),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(R.isSmall(context) ? 14 : 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF07E2B).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(R.isSmall(context) ? 10 : 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF07E2B),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medical_services, color: Colors.white, size: R.isSmall(context) ? 24 : 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đội Ngũ Bác Sĩ',
                      style: TextStyle(
                        fontSize: R.sp(context, 16),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F2E53),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chuyên gia thú y hàng đầu',
                      style: TextStyle(fontSize: R.sp(context, 12), color: const Color(0xFF4B5563)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 4.0, left: 8.0),
                child: Icon(Icons.arrow_forward_ios, color: Color(0xFFF07E2B), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
