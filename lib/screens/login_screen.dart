import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pet_care/screens/landing_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/screens/register_screen.dart';
import 'package:pet_care/screens/vet_dashboard_screen.dart';
import 'package:pet_care/screens/admin_dashboard_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_care/services/analytics_service.dart';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // serverClientId phải là Web Client ID của Firebase project hiện tại
    serverClientId: '988271144297-d2mno63bas8po4a3q9rls33ch8l72nba.apps.googleusercontent.com',
  );
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-warm: signOut ngay khi màn hình hiện — sẵn sàng cho lần nhấn nút
    _googleSignIn.signOut().ignore();
  }

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
      // Dùng trực tiếp userInfo từ login response — không cần gọi getMe() nữa
      final userInfo = session.userInfo;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userInfo', jsonEncode(userInfo));

      final String? userId = userInfo['_id'] ?? userInfo['id'] ?? userInfo['user']?['_id'];
      AnalyticsService().setUser(userId, role: userInfo['role']);

      if (!mounted) return;
      if (session.role == 'admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AdminDashboardScreen(user: userInfo)),
          (route) => false,
        );
      } else if (session.role == 'vet') {
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


  Future<void> _signInWithGoogle() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });
    try {
      debugPrint('[GoogleLogin] Bắt đầu đăng nhập Google...');
      // signOut đã pre-warm trong initState, gọi lại để đảm bảo nếu cần
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[GoogleLogin] Người dùng huỷ.');
        setState(() => _isGoogleLoading = false);
        return;
      }
      debugPrint('[GoogleLogin] Google user: ${googleUser.email}');

      // Song song: lấy authentication và khởi tạo SharedPreferences cùng lúc
      final results = await Future.wait([
        googleUser.authentication,
        SharedPreferences.getInstance(),
      ]);
      final googleAuth = results[0] as GoogleSignInAuthentication;
      final prefs = results[1] as SharedPreferences;

      final idToken = googleAuth.idToken;
      debugPrint('[GoogleLogin] idToken: ${idToken == null ? "NULL \u274c" : "${idToken.substring(0, 30)}... \u2705"}');

      if (idToken == null) {
        throw Exception('Không lấy được ID token. Kiểm tra serverClientId và Android OAuth Client.');
      }

      debugPrint('[GoogleLogin] Gửi idToken lên backend...');

      // Dùng firebase_auth để sign in và lấy Firebase ID Token thật
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final firebaseUserCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await firebaseUserCredential.user!.getIdToken();
      debugPrint('[GoogleLogin] Firebase ID Token OK: ${firebaseIdToken!.substring(0, 30)}...');

      // Lấy FCM Token để nhận thông báo
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        debugPrint('[FCM] Token: $fcmToken');
      } catch (e) {
        debugPrint('[FCM] Lỗi lấy token: $e');
      }

      final session = await _authService.firebaseLogin(idToken: firebaseIdToken, fcmToken: fcmToken ?? '');
      debugPrint('[GoogleLogin] Backend trả về token OK. Role: ${session.role}');

      final userInfo = session.userInfo;
      debugPrint('[GoogleLogin] userInfo: $userInfo');

      await prefs.setString('userInfo', jsonEncode(userInfo));
      
      final String? userId = userInfo['_id'] ?? userInfo['id'] ?? userInfo['user']?['_id'];
      AnalyticsService().setUser(userId, role: userInfo['role']);

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
    } catch (error, stackTrace) {
      debugPrint('══════════════════════════════════════');
      debugPrint('[GoogleLogin ERROR] $error');
      debugPrint('[StackTrace]\n$stackTrace');
      debugPrint('══════════════════════════════════════');

      if (!mounted) return;
      final errorMsg = error.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = errorMsg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập email' : null,
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
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập mật khẩu' : null,
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
                          const SizedBox(height: 16),
                          // ── Divider "Hoặc" ──
                          Row(
                            children: [
                              const Expanded(child: Divider(thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Hoặc',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: R.sp(context, 13),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // ── Google Login Button ──
                          OutlinedButton(
                            onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                              backgroundColor: Colors.white,
                            ),
                            child: _isGoogleLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                        height: 22,
                                        width: 22,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 22, color: Color(0xFF4285F4)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Đăng nhập bằng Google',
                                        style: TextStyle(
                                          color: const Color(0xFF3C4043),
                                          fontSize: R.sp(context, 14),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
