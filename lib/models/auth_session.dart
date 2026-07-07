class AuthSession {
  const AuthSession({required this.token, required this.role, required this.name});

  final String token;
  final String role;
  final String name;

  factory AuthSession.fromLoginPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final tokenValue = dataMap?['accessToken'] ?? dataMap?['token'] ?? payload['accessToken'] ?? payload['token'];
    final user = dataMap?['user'];
    final roleValue = _extractRole(user, payload);
    final nameValue = _extractName(user, payload);

    return AuthSession(
      token: tokenValue?.toString() ?? '',
      role: roleValue?.toString().toLowerCase() ?? 'user',
      name: nameValue?.toString() ?? 'User',
    );
  }

  static String? _extractRole(dynamic user, Map<String, dynamic> payload) {
    if (user is Map) {
      final role = user['role'] ?? user['roles'];
      if (role is List) {
        return role.isNotEmpty ? role.first.toString() : null;
      }
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
