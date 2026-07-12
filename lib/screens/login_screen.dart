import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pet_care/screens/landing_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/screens/register_screen.dart';
import 'package:pet_care/screens/vet_dashboard_screen.dart';
import 'package:pet_care/screens/admin_dashboard_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final session = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final userInfo = await _authService.getMe(session.token);
      userInfo['token'] = session.token;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userInfo', jsonEncode(userInfo));

      if (!mounted) return;
      if (userInfo['role'] == 'admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AdminDashboardScreen(user: userInfo)),
          (route) => false,
        );
      } else if (userInfo['role'] == 'vet') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => VetDashboardScreen(user: userInfo)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LandingScreen(user: userInfo)),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      String friendlyError = 'Email hoặc mật khẩu không chính xác!';
      setState(() => _errorMessage = friendlyError);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(friendlyError, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = R.cardPadding(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F2E53)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9E6), Color(0xFFFFD740)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: R.pagePadding(context),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(cp),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.pets, size: R.iconLg(context), color: const Color(0xFFF07E2B)),
                          SizedBox(height: R.isSmall(context) ? 10 : 16),
                          Text(
                            'Đăng nhập PetCare',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: R.sp(context, 24),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F2E53),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chào mừng bạn quay trở lại!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: R.sp(context, 13),
                            ),
                          ),
                          SizedBox(height: R.isSmall(context) ? 20 : 28),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFF07E2B), width: 2),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Nhập email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFF07E2B), width: 2),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                          ),
                          SizedBox(height: R.isSmall(context) ? 18 : 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD740),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F2E53)))
                                : Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      color: const Color(0xFF0F2E53),
                                      fontSize: R.sp(context, 15),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: R.sp(context, 12)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Chưa có tài khoản? ', style: TextStyle(fontSize: R.sp(context, 13))),
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                child: Text(
                                  'Đăng ký ngay',
                                  style: TextStyle(
                                    color: const Color(0xFFF07E2B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: R.sp(context, 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
