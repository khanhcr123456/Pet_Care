import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pet_care/config/app_config.dart';
import 'package:pet_care/screens/landing_screen.dart';
import 'package:pet_care/screens/admin_dashboard_screen.dart';
import 'package:pet_care/screens/vet_dashboard_screen.dart';
import 'package:pet_care/screens/appointments_screen.dart';
import 'package:pet_care/screens/purchase_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationNavigation(Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userInfoStr = prefs.getString('userInfo');
    if (userInfoStr != null) {
      final user = jsonDecode(userInfoStr);
      
      if (data['screen'] == 'purchase_history' || data['orderId'] != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PurchaseHistoryScreen(user: user),
          ),
        );
        return;
      }

      if (data['appointmentId'] != null || data['status'] != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) {
              if (user['role'] == 'vet') return VetDashboardScreen(user: user);
              return AppointmentsScreen(user: user, isEmbedded: false);
            }
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Navigation error: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Yêu cầu quyền thông báo (đặc biệt quan trọng với Android 13+ và iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Khởi tạo flutter_local_notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        _handleNotificationNavigation(data);
      }
    },
  );

  // Cấu hình Channel cho Android để thông báo popup lên trên cùng màn hình
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'Kênh cho các thông báo quan trọng.', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Xử lý khi bấm vào thông báo từ background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationNavigation(message.data);
      });
    }
  });

  // Lắng nghe thông báo khi ứng dụng đang mở màn hình (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  });
  final prefs = await SharedPreferences.getInstance();
  final userInfoStr = prefs.getString('userInfo');
  Map<String, dynamic>? userInfo;
  
  if (userInfoStr != null) {
    try {
      userInfo = jsonDecode(userInfoStr);
    } catch (e) {
      // Ignored
    }
  }

  runApp(PetCareApp(initialUser: userInfo));
}

class PetCareApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  
  const PetCareApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen = const LandingScreen();
    
    if (initialUser != null) {
      final user = initialUser!;
      final role = user['role'];
      if (role == 'admin') {
        homeScreen = AdminDashboardScreen(user: user);
      } else if (role == 'vet') {
        homeScreen = VetDashboardScreen(user: user);
      } else {
        homeScreen = LandingScreen(user: user);
      }
    }

    return MaterialApp(
      title: AppConfig.appTitle,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD740))),
      home: homeScreen,
    );
  }
}

