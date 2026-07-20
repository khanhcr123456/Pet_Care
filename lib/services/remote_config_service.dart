import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService extends ChangeNotifier {
  // Biến thành Singleton để có thể gọi ở bất cứ file UI nào
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      // 1. Khai báo các giá trị mặc định cho App Pet Care
      await _remoteConfig.setDefaults(const {
        "app_theme_event": "NORMAL", // NORMAL, TET, HALLOWEEN, NOEL
      });

      // 2. Cài đặt thời gian đồng bộ
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(seconds: 0),
      ));

      // 3. Lấy cấu hình từ Firebase về máy (lần đầu)
      await _remoteConfig.fetchAndActivate();

      // 4. 🔥 LẮNG NGHE SỰ THAY ĐỔI THEO THỜI GIAN THỰC (REALTIME)
      _remoteConfig.onConfigUpdated.listen((event) async {
        await _remoteConfig.activate(); // Kích hoạt ngay lập tức bản cập nhật
        notifyListeners(); // Ra lệnh cho giao diện UI tự động vẽ lại
        debugPrint("Có dữ liệu mới từ Firebase, giao diện đã tự Update!");
      });

      debugPrint("Remote Config: Cập nhật thành công!");
    } catch (e) {
      debugPrint("Lỗi tải Remote Config: $e");
    }
  }

  // CÁC HÀM GETTER ĐỂ GỌI TRÊN GIAO DIỆN CỦA BẠN (UI):
  
  // Lấy ra Giao diện Sự Kiện hiện tại
  String get themeEvent => _remoteConfig.getString("app_theme_event");

  // Hàm ép tải lại thủ công khi kéo F5 (Refresh) 
  Future<void> forceFetchAndActivate() async {
    try {
      await _remoteConfig.fetchAndActivate();
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi ép tải lại Remote Config: $e");
    }
  }
}
