import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
      // 🔥 BẮN THÊM CUSTOM EVENT ĐỂ HIỆN NGAY TRÊN BẢNG "EVENT COUNT" BÊN PHẢI CỦA BẠN!
      await _analytics.logEvent(
        name: 'visit_page',
        parameters: {'page_name': screenName},
      );
      print("Analytics: Đã ghi nhận truy cập màn hình $screenName");
    } catch (e) {
      print("Analytics Error: $e");
    }
  }

  Future<void> setUser(String? userId, {String? role}) async {
    try {
      await _analytics.setUserId(id: userId);
      if (role != null) {
        await _analytics.setUserProperty(name: 'user_role', value: role);
      }
      print("Analytics: Đã gắn danh tính UserID = $userId (Role = $role)");
    } catch (e) {
      print("Analytics Error (setUser): $e");
    }
  }

  Future<void> logCustomEvent(String eventName, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      print("Analytics: Đã ghi nhận sự kiện $eventName");
    } catch (e) {
      print("Analytics Error: $e");
    }
  }
}
