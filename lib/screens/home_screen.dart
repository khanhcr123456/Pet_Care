import 'package:flutter/material.dart';
import 'package:pet_care/models/auth_session.dart';
import 'package:pet_care/screens/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final isAdmin = session.role.toLowerCase() == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text(isAdmin ? 'Trang quản trị' : 'Trang người dùng')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, ${session.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Vai trò: ${session.role.toUpperCase()}'),
            const SizedBox(height: 24),
            if (isAdmin)
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quản lý người dùng và thú cưng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('• Quản lý dashboard\n• Quản lý tài khoản\n• Theo dõi lịch hẹn'),
                  ],
                ),
              )
            else
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giao diện người dùng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('• Xem thú cưng\n• Đặt lịch khám\n• Theo dõi hồ sơ sức khỏe'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}
