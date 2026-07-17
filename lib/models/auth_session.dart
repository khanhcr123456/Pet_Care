class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.name,
    required this.userInfo,
  });

  final String token;
  final String role;
  final String name;
  /// Toàn bộ thông tin user từ login response (tránh gọi thêm getMe())
  final Map<String, dynamic> userInfo;

  factory AuthSession.fromLoginPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final tokenValue = dataMap?['accessToken'] ?? dataMap?['token']
        ?? payload['accessToken'] ?? payload['token'];

    // Lấy user object từ các vị trí có thể có trong response
    final rawUser = dataMap?['user'] ?? dataMap ?? payload;
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : <String, dynamic>{};

    final roleValue = _extractRole(user, payload);
    final nameValue = _extractName(user, payload);

    // Gắn token vào userInfo để dùng ngay
    final userInfo = Map<String, dynamic>.from(user);
    userInfo['token'] = tokenValue?.toString() ?? '';

    return AuthSession(
      token: tokenValue?.toString() ?? '',
      role: roleValue?.toString().toLowerCase() ?? 'user',
      name: nameValue?.toString() ?? 'User',
      userInfo: userInfo,
    );
  }

  static String? _extractRole(dynamic user, Map<String, dynamic> payload) {
    if (user is Map) {
      final role = user['role'] ?? user['roles'];
      if (role is List) return role.isNotEmpty ? role.first.toString() : null;
      return role?.toString();
    }
    return payload['role']?.toString() ?? payload['userRole']?.toString();
  }

  static String? _extractName(dynamic user, Map<String, dynamic> payload) {
    if (user is Map) {
      return user['name']?.toString() ?? user['fullName']?.toString();
    }
    return payload['name']?.toString() ?? payload['fullName']?.toString();
  }
}
