import 'package:flutter/material.dart';
import 'package:pet_care/models/auth_session.dart';
import 'package:pet_care/screens/login_screen.dart';
import 'package:pet_care/utils/responsive.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final isAdmin = session.role.toLowerCase() == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Trang quản trị' : 'Trang người dùng',
          style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: R.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, ${session.name}',
                style: TextStyle(fontSize: R.sp(context, 22), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Vai trò: ${session.role.toUpperCase()}', style: TextStyle(fontSize: R.sp(context, 14))),
              const SizedBox(height: 24),
              if (isAdmin)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quản lý người dùng và thú cưng', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('• Quản lý dashboard\n• Quản lý tài khoản\n• Theo dõi lịch hẹn', style: TextStyle(fontSize: R.sp(context, 14))),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Giao diện người dùng', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('• Xem thú cưng\n• Đặt lịch khám\n• Theo dõi hồ sơ sức khỏe', style: TextStyle(fontSize: R.sp(context, 14))),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xác nhận đăng xuất'),
                        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 12 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Đăng xuất', style: TextStyle(fontSize: R.sp(context, 15))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
